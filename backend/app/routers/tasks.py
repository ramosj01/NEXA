"""Chat-to-Task: turn messages into tracked, assignable tasks."""

from anyio.from_thread import run as run_async
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..models import Message, Task, TaskStatus, User
from ..realtime import manager
from ..schemas import TaskCreate, TaskFromMessage, TaskOut, TaskUpdate
from ..services import member_ids, require_member

router = APIRouter(tags=["tasks"])


def _check_assignee(db: Session, conversation_id: str, assignee_id: str | None) -> None:
    if assignee_id is not None and assignee_id not in member_ids(db, conversation_id):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "assignee is not in this conversation")


def _announce(db: Session, task: Task, kind: str) -> None:
    run_async(
        manager.publish,
        member_ids(db, task.conversation_id),
        {"type": kind, "task": TaskOut.model_validate(task).model_dump(mode="json")},
    )


@router.post(
    "/conversations/{conversation_id}/tasks",
    response_model=TaskOut,
    status_code=status.HTTP_201_CREATED,
)
def create_task(
    conversation_id: str,
    data: TaskCreate,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    require_member(db, conversation_id, user)
    _check_assignee(db, conversation_id, data.assignee_id)
    if data.source_message_id is not None:
        src = db.get(Message, data.source_message_id)
        if src is None or src.conversation_id != conversation_id:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "source message not in conversation")
    task = Task(conversation_id=conversation_id, created_by=user.id, **data.model_dump())
    db.add(task)
    db.commit()
    _announce(db, task, "task.created")
    return task


@router.post("/messages/{message_id}/task", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def task_from_message(
    message_id: str,
    data: TaskFromMessage,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """One-tap conversion: the message text becomes the task title unless overridden."""
    msg = db.get(Message, message_id)
    if msg is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "message not found")
    require_member(db, msg.conversation_id, user)
    _check_assignee(db, msg.conversation_id, data.assignee_id)
    title = data.title or msg.body.strip().splitlines()[0][:300]
    task = Task(
        conversation_id=msg.conversation_id,
        source_message_id=msg.id,
        title=title,
        assignee_id=data.assignee_id,
        due_at=data.due_at,
        created_by=user.id,
    )
    db.add(task)
    db.commit()
    _announce(db, task, "task.created")
    return task


@router.get("/conversations/{conversation_id}/tasks", response_model=list[TaskOut])
def list_tasks(
    conversation_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)
):
    require_member(db, conversation_id, user)
    return list(
        db.scalars(
            select(Task)
            .where(Task.conversation_id == conversation_id)
            .order_by(Task.status.desc(), Task.due_at.is_(None), Task.due_at, Task.created_at)
        )
    )


@router.get("/tasks/mine", response_model=list[TaskOut])
def my_tasks(
    include_done: bool = False,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    q = select(Task).where(Task.assignee_id == user.id)
    if not include_done:
        q = q.where(Task.status == TaskStatus.open)
    return list(db.scalars(q.order_by(Task.due_at.is_(None), Task.due_at, Task.created_at)))


@router.patch("/tasks/{task_id}", response_model=TaskOut)
def update_task(
    task_id: str,
    data: TaskUpdate,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    task = db.get(Task, task_id)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "task not found")
    require_member(db, task.conversation_id, user)
    changes = data.model_dump(exclude_unset=True)
    if "assignee_id" in changes:
        _check_assignee(db, task.conversation_id, changes["assignee_id"])
    for k, v in changes.items():
        setattr(task, k, v)
    db.commit()
    _announce(db, task, "task.updated")
    return task
