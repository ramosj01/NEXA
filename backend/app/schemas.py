from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from .models import InboxCategory, TaskStatus


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class UserOut(ORM):
    id: str
    display_name: str


class ConversationCreate(BaseModel):
    member_ids: list[str] = Field(min_length=1)
    title: str | None = Field(default=None, max_length=200)
    is_group: bool = False


class ConversationOut(ORM):
    id: str
    title: str | None
    is_group: bool
    created_by: str
    created_at: datetime
    member_ids: list[str]


class CategoryUpdate(BaseModel):
    category: InboxCategory


class MessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=10_000)
    # Client-generated id; resending the same one is idempotent (offline queue).
    client_id: str | None = Field(default=None, max_length=64)


class MessageOut(ORM):
    id: str
    conversation_id: str
    sender_id: str
    client_id: str | None
    body: str
    created_at: datetime


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=300)
    assignee_id: str | None = None
    due_at: datetime | None = None
    source_message_id: str | None = None


class TaskFromMessage(BaseModel):
    title: str | None = Field(default=None, max_length=300)
    assignee_id: str | None = None
    due_at: datetime | None = None


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=300)
    assignee_id: str | None = None
    due_at: datetime | None = None
    status: TaskStatus | None = None


class TaskOut(ORM):
    id: str
    conversation_id: str
    source_message_id: str | None
    title: str
    assignee_id: str | None
    due_at: datetime | None
    status: TaskStatus
    created_by: str
    created_at: datetime


class PollCreate(BaseModel):
    question: str = Field(min_length=1, max_length=300)
    options: list[str] = Field(min_length=2, max_length=12)


class VoteIn(BaseModel):
    option_id: str


class DecisionIn(BaseModel):
    option_id: str
    note: str | None = Field(default=None, max_length=2000)


class PollOptionOut(BaseModel):
    id: str
    text: str
    votes: int


class PollOut(BaseModel):
    id: str
    conversation_id: str
    question: str
    created_by: str
    created_at: datetime
    closed_at: datetime | None
    options: list[PollOptionOut]
    my_vote: str | None
    decision_option_id: str | None
    decision_note: str | None


class InboxItem(BaseModel):
    conversation: ConversationOut
    category: InboxCategory
    last_message: MessageOut | None
    unread_count: int
    awaiting_my_reply: bool
    open_tasks_for_me: int
