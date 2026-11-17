import os

os.environ["NEXA_DATABASE_URL"] = "sqlite://"
os.environ["NEXA_AUTH_MODE"] = "dev"

import pytest
from fastapi.testclient import TestClient

from app.db import Base, engine
from app.main import app


@pytest.fixture()
def client():
    Base.metadata.drop_all(engine)
    with TestClient(app) as c:
        yield c


def auth(uid: str) -> dict:
    return {"Authorization": f"Bearer dev:{uid}:{uid.title()}"}


@pytest.fixture()
def users(client):
    for uid in ("alice", "bob", "carol", "mallory"):
        assert client.get("/me", headers=auth(uid)).status_code == 200
    return {u: auth(u) for u in ("alice", "bob", "carol", "mallory")}


@pytest.fixture()
def group(client, users):
    r = client.post(
        "/conversations",
        json={"member_ids": ["bob", "carol"], "title": "Project", "is_group": True},
        headers=users["alice"],
    )
    assert r.status_code == 201
    return r.json()["id"]
