"""Database models for the NEXA MVP.

SmartSpace layers map onto these tables:
  CHAT     -> Conversation, Membership, Message
  ACTIONS  -> Task, Poll, PollOption, Vote (decisions)
"""

import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def _id() -> str:
    return uuid.uuid4().hex


def _now() -> datetime:
    return datetime.now(timezone.utc)


class InboxCategory(str, enum.Enum):
    personal = "personal"
    work = "work"
    important = "important"


class TaskStatus(str, enum.Enum):
    open = "open"
    done = "done"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)  # Firebase UID
    display_name: Mapped[str] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Conversation(Base):
    __tablename__ = "conversations"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_id)
    title: Mapped[str | None] = mapped_column(String(200))
    is_group: Mapped[bool] = mapped_column(Boolean, default=False)
    created_by: Mapped[str] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    members: Mapped[list["Membership"]] = relationship(
        back_populates="conversation", cascade="all, delete-orphan"
    )


class Membership(Base):
    __tablename__ = "memberships"

    conversation_id: Mapped[str] = mapped_column(
        ForeignKey("conversations.id"), primary_key=True
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    category: Mapped[InboxCategory] = mapped_column(
        Enum(InboxCategory), default=InboxCategory.personal
    )
    last_read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    conversation: Mapped[Conversation] = relationship(back_populates="members")


class Message(Base):
    __tablename__ = "messages"
    # client_id lets offline-queued messages be retried without duplicates.
    __table_args__ = (UniqueConstraint("sender_id", "client_id"),)

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_id)
    conversation_id: Mapped[str] = mapped_column(
        ForeignKey("conversations.id"), index=True
    )
    sender_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    client_id: Mapped[str | None] = mapped_column(String(64))
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, index=True
    )


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_id)
    conversation_id: Mapped[str] = mapped_column(
        ForeignKey("conversations.id"), index=True
    )
    source_message_id: Mapped[str | None] = mapped_column(ForeignKey("messages.id"))
    title: Mapped[str] = mapped_column(String(300))
    assignee_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[TaskStatus] = mapped_column(Enum(TaskStatus), default=TaskStatus.open)
    created_by: Mapped[str] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Poll(Base):
    __tablename__ = "polls"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_id)
    conversation_id: Mapped[str] = mapped_column(
        ForeignKey("conversations.id"), index=True
    )
    question: Mapped[str] = mapped_column(String(300))
    created_by: Mapped[str] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # The recorded final decision (Decision Rooms).
    decision_option_id: Mapped[str | None] = mapped_column(String(32))
    decision_note: Mapped[str | None] = mapped_column(Text)

    options: Mapped[list["PollOption"]] = relationship(
        back_populates="poll", cascade="all, delete-orphan", order_by="PollOption.position"
    )
    votes: Mapped[list["Vote"]] = relationship(cascade="all, delete-orphan")


class PollOption(Base):
    __tablename__ = "poll_options"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_id)
    poll_id: Mapped[str] = mapped_column(ForeignKey("polls.id"), index=True)
    text: Mapped[str] = mapped_column(String(200))
    position: Mapped[int] = mapped_column(default=0)

    poll: Mapped[Poll] = relationship(back_populates="options")


class Vote(Base):
    __tablename__ = "votes"

    poll_id: Mapped[str] = mapped_column(ForeignKey("polls.id"), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    option_id: Mapped[str] = mapped_column(ForeignKey("poll_options.id"))
