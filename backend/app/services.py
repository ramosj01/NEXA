"""Shared domain logic used by both the REST routes and the WebSocket."""

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Conversation, Membership, Message, Poll, User
from .schemas import ConversationOut, MessageOut, PollOptionOut, PollOut


def require_member(db: Session, conversation_id: str, user: User) -> Membership:
    m = db.get(Membership, (conversation_id, user.id))
    if m is None:
        # 404 rather than 403 so conversation ids can't be probed.
        raise HTTPException(status.HTTP_404_NOT_FOUND, "conversation not found")
    return m


def member_ids(db: Session, conversation_id: str) -> list[str]:
    return list(
        db.scalars(
            select(Membership.user_id).where(Membership.conversation_id == conversation_id)
        )
    )


def conversation_out(conv: Conversation) -> ConversationOut:
    return ConversationOut(
        id=conv.id,
        title=conv.title,
        is_group=conv.is_group,
        created_by=conv.created_by,
        created_at=conv.created_at,
        member_ids=sorted(m.user_id for m in conv.members),
    )


def create_message(
    db: Session, user: User, conversation_id: str, body: str, client_id: str | None
) -> tuple[Message, bool]:
    """Persist a message. Returns (message, created); created is False on a retry."""
    require_member(db, conversation_id, user)
    if client_id:
        existing = db.scalar(
            select(Message).where(
                Message.sender_id == user.id, Message.client_id == client_id
            )
        )
        if existing is not None:
            return existing, False
    msg = Message(
        conversation_id=conversation_id, sender_id=user.id, body=body, client_id=client_id
    )
    db.add(msg)
    # Sending a message implies the sender has read the conversation up to it.
    db.flush()
    db.get(Membership, (conversation_id, user.id)).last_read_at = msg.created_at
    db.commit()
    return msg, True


def message_event(msg: Message) -> dict:
    return {"type": "message.new", "message": MessageOut.model_validate(msg).model_dump(mode="json")}


def poll_out(poll: Poll, viewer_id: str) -> PollOut:
    counts: dict[str, int] = {}
    mine = None
    for v in poll.votes:
        counts[v.option_id] = counts.get(v.option_id, 0) + 1
        if v.user_id == viewer_id:
            mine = v.option_id
    return PollOut(
        id=poll.id,
        conversation_id=poll.conversation_id,
        question=poll.question,
        created_by=poll.created_by,
        created_at=poll.created_at,
        closed_at=poll.closed_at,
        options=[
            PollOptionOut(id=o.id, text=o.text, votes=counts.get(o.id, 0))
            for o in poll.options
        ],
        my_vote=mine,
        decision_option_id=poll.decision_option_id,
        decision_note=poll.decision_note,
    )
