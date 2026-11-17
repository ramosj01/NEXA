from .conftest import auth


def test_auth_required(client):
    assert client.get("/me").status_code == 401
    assert client.get("/me", headers={"Authorization": "Bearer nope"}).status_code == 401


def test_direct_conversation_rules(client, users):
    r = client.post("/conversations", json={"member_ids": ["bob", "carol"]}, headers=users["alice"])
    assert r.status_code == 400
    r = client.post("/conversations", json={"member_ids": ["ghost"]}, headers=users["alice"])
    assert r.status_code == 400
    r = client.post("/conversations", json={"member_ids": ["bob"]}, headers=users["alice"])
    assert r.status_code == 201
    assert r.json()["member_ids"] == ["alice", "bob"]


def test_messages_and_offline_retry(client, users, group):
    url = f"/conversations/{group}/messages"
    first = client.post(url, json={"body": "hi", "client_id": "c1"}, headers=users["alice"]).json()
    retry = client.post(url, json={"body": "hi", "client_id": "c1"}, headers=users["alice"]).json()
    assert first["id"] == retry["id"]
    client.post(url, json={"body": "hey"}, headers=users["bob"])
    msgs = client.get(url, headers=users["carol"]).json()
    assert [m["body"] for m in msgs] == ["hey", "hi"]


def test_non_members_cannot_see_conversation(client, users, group):
    h = users["mallory"]
    assert client.get(f"/conversations/{group}", headers=h).status_code == 404
    assert client.get(f"/conversations/{group}/messages", headers=h).status_code == 404
    assert client.post(f"/conversations/{group}/messages", json={"body": "x"}, headers=h).status_code == 404
    assert client.get(f"/conversations/{group}/tasks", headers=h).status_code == 404


def test_chat_to_task(client, users, group):
    m = client.post(
        f"/conversations/{group}/messages",
        json={"body": "Submit the report Friday\nthanks"},
        headers=users["alice"],
    ).json()
    r = client.post(f"/messages/{m['id']}/task", json={"assignee_id": "bob"}, headers=users["carol"])
    assert r.status_code == 201
    task = r.json()
    assert task["title"] == "Submit the report Friday"
    assert task["source_message_id"] == m["id"]

    assert [t["id"] for t in client.get("/tasks/mine", headers=users["bob"]).json()] == [task["id"]]
    r = client.post(f"/messages/{m['id']}/task", json={"assignee_id": "mallory"}, headers=users["alice"])
    assert r.status_code == 400
    assert client.post(f"/messages/{m['id']}/task", json={}, headers=users["mallory"]).status_code == 404

    r = client.patch(f"/tasks/{task['id']}", json={"status": "done"}, headers=users["bob"])
    assert r.json()["status"] == "done"
    assert client.get("/tasks/mine", headers=users["bob"]).json() == []


def test_poll_vote_and_decision(client, users, group):
    r = client.post(
        f"/conversations/{group}/polls",
        json={"question": "Meeting day?", "options": ["Mon", "Tue"]},
        headers=users["alice"],
    )
    poll = r.json()
    mon, tue = (o["id"] for o in poll["options"])
    client.put(f"/polls/{poll['id']}/vote", json={"option_id": mon}, headers=users["bob"])
    client.put(f"/polls/{poll['id']}/vote", json={"option_id": tue}, headers=users["bob"])  # change vote
    p = client.put(f"/polls/{poll['id']}/vote", json={"option_id": tue}, headers=users["carol"]).json()
    assert [o["votes"] for o in p["options"]] == [0, 2]
    assert p["my_vote"] == tue

    assert client.post(f"/polls/{poll['id']}/decision", json={"option_id": tue}, headers=users["bob"]).status_code == 403
    d = client.post(f"/polls/{poll['id']}/decision", json={"option_id": tue, "note": "Tue 10am"}, headers=users["alice"])
    assert d.json()["decision_option_id"] == tue
    assert client.put(f"/polls/{poll['id']}/vote", json={"option_id": mon}, headers=users["bob"]).status_code == 409
    history = client.get(f"/conversations/{group}/polls?decided_only=true", headers=users["carol"]).json()
    assert [h["decision_note"] for h in history] == ["Tue 10am"]


def test_poll_rejects_duplicate_options(client, users, group):
    r = client.post(
        f"/conversations/{group}/polls",
        json={"question": "?", "options": ["A", "A "]},
        headers=users["alice"],
    )
    assert r.status_code == 400


def test_smart_inbox(client, users, group):
    dm = client.post("/conversations", json={"member_ids": ["bob"]}, headers=users["alice"]).json()["id"]
    client.post(f"/conversations/{group}/messages", json={"body": "a"}, headers=users["bob"])
    client.post(f"/conversations/{group}/messages", json={"body": "b"}, headers=users["carol"])
    client.post(f"/conversations/{dm}/messages", json={"body": "sent by me"}, headers=users["alice"])

    items = client.get("/inbox", headers=users["alice"]).json()
    assert items[0]["conversation"]["id"] == group
    assert items[0]["unread_count"] == 2 and items[0]["awaiting_my_reply"]
    assert items[1]["unread_count"] == 0 and not items[1]["awaiting_my_reply"]

    client.post(f"/conversations/{group}/read", headers=users["alice"])
    assert client.get("/inbox", headers=users["alice"]).json()[0]["unread_count"] == 0

    client.put(f"/conversations/{dm}/category", json={"category": "work"}, headers=users["alice"])
    work = client.get("/inbox?category=work", headers=users["alice"]).json()
    assert [i["conversation"]["id"] for i in work] == [dm]


def test_websocket_delivery(client, users, group):
    with client.websocket_connect("/ws?token=dev:bob") as bob, client.websocket_connect(
        "/ws?token=dev:alice"
    ) as alice:
        alice.send_json({"type": "message.send", "conversation_id": group, "body": "live", "client_id": "w1"})
        assert bob.receive_json()["message"]["body"] == "live"
        assert alice.receive_json()["message"]["body"] == "live"

        # REST sends are fanned out over the socket too.
        client.post(f"/conversations/{group}/messages", json={"body": "rest"}, headers=auth("carol"))
        assert bob.receive_json()["message"]["body"] == "rest"

        alice.send_json({"type": "typing", "conversation_id": group})
        assert bob.receive_json() == {"type": "typing", "conversation_id": group, "user_id": "alice"}


def test_websocket_rejects_non_member(client, users, group):
    with client.websocket_connect("/ws?token=dev:mallory") as ws:
        ws.send_json({"type": "message.send", "conversation_id": group, "body": "x"})
        assert ws.receive_json()["type"] == "error"
