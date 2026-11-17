"""Decision Rooms: polls, votes and recorded decisions."""

from datetime import datetime, timezone

from anyio.from_thread import run as run_async
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..models import Poll, PollOption, User, Vote
from ..realtime import manager
from ..schemas import DecisionIn, PollCreate, PollOut, VoteIn
from ..services import member_ids, poll_out, require_member

router = APIRouter(tags=["decisions"])


def _get_poll(db: Session, poll_id: str, user: User) -> Poll:
    poll = db.get(Poll, poll_id)
    if poll is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "poll not found")
    require_member(db, poll.conversation_id, user)
    return poll


def _option(poll: Poll, option_id: str) -> PollOption:
    for o in poll.options:
        if o.id == option_id:
            return o
    raise HTTPException(status.HTTP_400_BAD_REQUEST, "option is not part of this poll")


def _announce(db: Session, poll: Poll) -> None:
    # Viewer-neutral payload: clients refetch for their own my_vote.
    event = {"type": "poll.updated", "poll": poll_out(poll, "").model_dump(mode="json")}
    run_async(manager.publish, member_ids(db, poll.conversation_id), event)


@router.post(
    "/conversations/{conversation_id}/polls",
    response_model=PollOut,
    status_code=status.HTTP_201_CREATED,
)
def create_poll(
    conversation_id: str,
    data: PollCreate,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    require_member(db, conversation_id, user)
    texts = [t.strip() for t in data.options if t.strip()]
    if len(texts) < 2 or len(set(texts)) != len(texts):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "need at least two distinct options")
    poll = Poll(conversation_id=conversation_id, question=data.question, created_by=user.id)
    poll.options = [PollOption(text=t, position=i) for i, t in enumerate(texts)]
    db.add(poll)
    db.commit()
    _announce(db, poll)
    return poll_out(poll, user.id)


@router.get("/conversations/{conversation_id}/polls", response_model=list[PollOut])
def list_polls(
    conversation_id: str,
    decided_only: bool = False,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """All polls, or with ``decided_only`` the conversation's decision history."""
    require_member(db, conversation_id, user)
    q = select(Poll).where(Poll.conversation_id == conversation_id)
    if decided_only:
        q = q.where(Poll.decision_option_id.is_not(None))
    return [poll_out(p, user.id) for p in db.scalars(q.order_by(Poll.created_at.desc()))]


@router.put("/polls/{poll_id}/vote", response_model=PollOut)
def vote(
    poll_id: str,
    data: VoteIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    poll = _get_poll(db, poll_id, user)
    if poll.closed_at is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "poll is closed")
    _option(poll, data.option_id)
    existing = db.get(Vote, (poll.id, user.id))
    if existing is None:
        db.add(Vote(poll_id=poll.id, user_id=user.id, option_id=data.option_id))
    else:
        existing.option_id = data.option_id
    db.commit()
    db.refresh(poll)
    _announce(db, poll)
    return poll_out(poll, user.id)


@router.post("/polls/{poll_id}/decision", response_model=PollOut)
def record_decision(
    poll_id: str,
    data: DecisionIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Close the poll and record the final decision. Only the poll creator may decide."""
    poll = _get_poll(db, poll_id, user)
    if poll.created_by != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "only the poll creator can record the decision")
    if poll.closed_at is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "decision already recorded")
    _option(poll, data.option_id)
    poll.decision_option_id = data.option_id
    poll.decision_note = data.note
    poll.closed_at = datetime.now(timezone.utc)
    db.commit()
    _announce(db, poll)
    return poll_out(poll, user.id)
