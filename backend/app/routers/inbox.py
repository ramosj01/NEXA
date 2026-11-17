"""Smart Inbox: categorised conversations, unread counts and pending replies."""

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..models import InboxCategory, Membership, Message, Task, TaskStatus, User
from ..schemas import InboxItem, MessageOut
from ..services import conversation_out

router = APIRouter(tags=["inbox"])


@router.get("/inbox", response_model=list[InboxItem])
def inbox(
    category: InboxCategory | None = None,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Conversations ordered by priority: awaiting my reply, then unread, then recency.

    ``awaiting_my_reply`` is a simple heuristic for the MVP (the latest message
    is from someone else); AI urgency scoring can refine it in a later version.
    """
    q = select(Membership).where(Membership.user_id == user.id)
    if category is not None:
        q = q.where(Membership.category == category)

    items: list[InboxItem] = []
    for m in db.scalars(q):
        conv_id = m.conversation_id
        last = db.scalar(
            select(Message)
            .where(Message.conversation_id == conv_id)
            .order_by(Message.created_at.desc())
            .limit(1)
        )
        unread_q = select(func.count()).select_from(Message).where(
            Message.conversation_id == conv_id, Message.sender_id != user.id
        )
        if m.last_read_at is not None:
            unread_q = unread_q.where(Message.created_at > m.last_read_at)
        open_tasks = db.scalar(
            select(func.count()).select_from(Task).where(
                Task.conversation_id == conv_id,
                Task.assignee_id == user.id,
                Task.status == TaskStatus.open,
            )
        )
        items.append(
            InboxItem(
                conversation=conversation_out(m.conversation),
                category=m.category,
                last_message=MessageOut.model_validate(last) if last else None,
                unread_count=db.scalar(unread_q) or 0,
                awaiting_my_reply=last is not None and last.sender_id != user.id,
                open_tasks_for_me=open_tasks or 0,
            )
        )

    def sort_key(i: InboxItem):
        ts = (i.last_message.created_at if i.last_message else i.conversation.created_at)
        return (not i.awaiting_my_reply, i.unread_count == 0, -ts.timestamp())

    return sorted(items, key=sort_key)
