"""NEXA Assistant: the tool loop runs against a scripted fake Claude client."""

from types import SimpleNamespace as NS

import pytest

from app.routers import assistant


class FakeClient:
    """Replays scripted responses and records each request's messages."""

    def __init__(self, script):
        self.script = list(script)
        self.requests = []
        self.beta = NS(messages=NS(create=self._create))

    def _create(self, **kwargs):
        self.requests.append({**kwargs, "messages": list(kwargs["messages"])})
        step = self.script.pop(0)
        return step(kwargs) if callable(step) else step


def tool_call(name, args, id_="t1"):
    return NS(
        stop_reason="tool_use",
        content=[NS(type="tool_use", id=id_, name=name, input=args)],
    )


def say(text):
    return NS(stop_reason="end_turn", content=[NS(type="text", text=text)])


@pytest.fixture()
def fake(monkeypatch):
    def install(*script):
        c = FakeClient(script)
        monkeypatch.setattr(assistant, "_client", c)
        return c

    return install


def test_inbox_then_create_task_and_send(client, users, group, fake):
    client.post(f"/conversations/{group}/messages", json={"body": "Can you send the deck?"}, headers=users["bob"])
    c = fake(
        tool_call("get_inbox", {}),
        tool_call(
            "create_task",
            {"conversation_id": group, "title": "Send the deck", "assignee_id": None, "due_at": "2026-11-20T09:00:00+00:00"},
        ),
        tool_call("send_message", {"conversation_id": group, "body": "On it!"}),
        say("Bob asked for the deck. I added a task and told the group you're on it."),
    )
    r = client.post(
        "/assistant/chat",
        json={"text": "What's waiting on me? Handle it.", "history": [{"role": "assistant", "text": "hi"}]},
        headers=users["alice"],
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["reply"].startswith("Bob asked")
    assert [a["tool"] for a in body["actions"]] == ["get_inbox", "create_task", "send_message"]
    assert all(a["ok"] for a in body["actions"])

    # Inbox result reached the model with names, not just ids.
    inbox_result = c.requests[1]["messages"][-1]["content"][0]["content"]
    assert "awaiting_my_reply" in inbox_result and "Bob" in inbox_result
    # History starting with an assistant turn was dropped so the request starts with user.
    assert c.requests[0]["messages"][0]["role"] == "user"

    tasks = client.get("/tasks/mine", headers=users["alice"]).json()
    assert [t["title"] for t in tasks] == ["Send the deck"]
    msgs = client.get(f"/conversations/{group}/messages", headers=users["bob"]).json()
    assert msgs[0]["body"] == "On it!" and msgs[0]["sender_id"] == "alice"


def test_tools_cannot_reach_other_users_chats(client, users, group, fake):
    fake(
        tool_call("read_conversation", {"conversation_id": group, "limit": 10}),
        tool_call("send_message", {"conversation_id": group, "body": "hacked"}, id_="t2"),
        say("I can't find that chat."),
    )
    r = client.post("/assistant/chat", json={"text": "read Project"}, headers=users["mallory"])
    assert r.status_code == 200
    assert [a["ok"] for a in r.json()["actions"]] == [False, False]
    assert client.get(f"/conversations/{group}/messages", headers=users["alice"]).json() == []


def test_complete_task_and_bad_due_date(client, users, group, fake):
    t = client.post(f"/conversations/{group}/tasks", json={"title": "Book room", "assignee_id": "bob"}, headers=users["alice"]).json()
    fake(
        tool_call("create_task", {"conversation_id": group, "title": "x", "assignee_id": None, "due_at": "tomorrow"}),
        tool_call("complete_task", {"task_id": t["id"]}, id_="t2"),
        say("Done."),
    )
    r = client.post("/assistant/chat", json={"text": "mark booking done"}, headers=users["bob"]).json()
    assert [a["ok"] for a in r["actions"]] == [False, True]
    assert client.get("/tasks/mine", headers=users["bob"]).json() == []


def test_refusal_is_spoken_politely(client, users, fake):
    fake(NS(stop_reason="refusal", content=[]))
    r = client.post("/assistant/chat", json={"text": "?"}, headers=users["alice"])
    assert r.status_code == 200 and "can't help" in r.json()["reply"]


def test_requires_auth(client):
    assert client.post("/assistant/chat", json={"text": "hi"}).status_code == 401
