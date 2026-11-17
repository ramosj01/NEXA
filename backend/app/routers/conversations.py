from datetime import datetime

from anyio.from_thread import run as run_async
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..models import Conversation, Membership, Message, User
from ..realtime import manager
from ..schemas import (
    CategoryUpdate,
    ConversationCreate,
    ConversationOut,
    MessageCreate,
    MessageOut,
)
from ..services import (
    conversation_out,
    create_message,
    member_ids,
    message_event,
    require_member,
)

router = APIRouter(prefix="/conversations", tags=["conversations"])


@router.post("", response_model=ConversationOut, status_code=status.HTTP_201_CREATED)
def create_conversation(
    data: ConversationCreate,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    ids = sorted(set(data.member_ids) | {user.id})
    found = set(db.scalars(select(User.id).where(User.id.in_(ids))))
    missing = [i for i in ids if i not in found]
    if missing:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"unknown users: {missing}")
    if not data.is_group and len(ids) != 2:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "a direct conversation has exactly one other member"
        )
    conv = Conversation(title=data.title, is_group=data.is_group, created_by=user.id)
    conv.members = [Membership(user_id=i) for i in ids]
    db.add(conv)
    db.commit()
    return conversation_out(conv)


@router.get("", response_model=list[ConversationOut])
def list_conversations(user: User = Depends(current_user), db: Session = Depends(get_db)):
    convs = db.scalars(
        select(Conversation)
        .join(Membership)
        .where(Membership.user_id == user.id)
        .order_by(Conversation.created_at.desc())
    )
    return [conversation_out(c) for c in convs]


@router.get("/{conversation_id}", response_model=ConversationOut)
def get_conversation(
    conversation_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)
):
    require_member(db, conversation_id, user)
    return conversation_out(db.get(Conversation, conversation_id))


@router.put("/{conversation_id}/category", status_code=status.HTTP_204_NO_CONTENT)
def set_category(
    conversation_id: str,
    data: CategoryUpdate,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    require_member(db, conversation_id, user).category = data.category
    db.commit()


@router.post("/{conversation_id}/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_read(
    conversation_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)
):
    m = require_member(db, conversation_id, user)
    latest = db.scalar(
        select(Message.created_at)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.created_at.desc())
        .limit(1)
    )
    if latest is not None:
        m.last_read_at = latest
        db.commit()


@router.get("/{conversation_id}/messages", response_model=list[MessageOut])
def list_messages(
    conversation_id: str,
    before: datetime | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Newest-first page of messages; pass the oldest ``created_at`` as ``before``."""
    require_member(db, conversation_id, user)
    q = select(Message).where(Message.conversation_id == conversation_id)
    if before is not None:
        q = q.where(Message.created_at < before)
    return list(db.scalars(q.order_by(Message.created_at.desc()).limit(limit)))


@router.post("/{conversation_id}/messages", response_model=MessageOut)
def send_message(
    conversation_id: str,
    data: MessageCreate,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    msg, created = create_message(db, user, conversation_id, data.body, data.client_id)
    if created:
        run_async(manager.publish, member_ids(db, conversation_id), message_event(msg))
    return msg
