from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from .auth import AuthError, current_user, user_from_token
from .config import settings
from .db import SessionLocal, get_db, init_db
from .models import User
from .realtime import manager
from .routers import assistant, conversations, inbox, polls, tasks
from .schemas import MessageCreate, UserOut
from .services import create_message, member_ids, message_event


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(title="NEXA API", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins),
    allow_methods=["*"],
    allow_headers=["*"],
)
for r in (conversations.router, tasks.router, polls.router, inbox.router, assistant.router):
    app.include_router(r)


@app.get("/health", tags=["meta"])
def health():
    return {"status": "ok"}


@app.get("/me", response_model=UserOut, tags=["users"])
def me(user: User = Depends(current_user)):
    return user


@app.get("/users", response_model=list[UserOut], tags=["users"])
def search_users(
    q: str = Query(min_length=1, max_length=100),
    _: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    pattern = f"%{q}%"
    return list(db.scalars(select(User).where(User.display_name.ilike(pattern)).limit(20)))


@app.websocket("/ws")
async def websocket(ws: WebSocket, token: str = Query()):
    """Real-time channel.

    Server -> client events: message.new, task.created, task.updated,
    poll.updated, typing, presence.
    Client -> server events:
      {"type": "message.send", "conversation_id", "body", "client_id"?}
      {"type": "typing", "conversation_id"}
    """
    with SessionLocal() as db:
        try:
            user = user_from_token(token, db)
        except AuthError:
            await ws.close(code=status.WS_1008_POLICY_VIOLATION)
            return
        user_id = user.id

    await manager.connect(user_id, ws)
    try:
        while True:
            data = await ws.receive_json()
            kind = data.get("type")
            conv_id = data.get("conversation_id")
            if conv_id is not None and not isinstance(conv_id, str):
                await ws.send_json({"type": "error", "detail": "conversation_id must be a string"})
                continue
            if kind == "message.send":
                try:
                    payload = MessageCreate.model_validate(data)
                except ValidationError as exc:
                    await ws.send_json({"type": "error", "detail": exc.errors(include_url=False)})
                    continue
                with SessionLocal() as db:
                    try:
                        msg, created = create_message(
                            db, db.get(User, user_id), conv_id, payload.body, payload.client_id
                        )
                    except HTTPException as exc:
                        await ws.send_json({"type": "error", "detail": exc.detail})
                        continue
                    targets = member_ids(db, conv_id)
                event = message_event(msg)
                if created:
                    await manager.publish(targets, event)
                else:  # retry of an already-stored message: ack only to the sender
                    await ws.send_json(event)
            elif kind == "typing" and conv_id:
                with SessionLocal() as db:
                    targets = member_ids(db, conv_id)
                if user_id in targets:
                    await manager.publish(
                        [t for t in targets if t != user_id],
                        {"type": "typing", "conversation_id": conv_id, "user_id": user_id},
                    )
            else:
                await ws.send_json({"type": "error", "detail": f"unknown event {kind!r}"})
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(user_id, ws)
