"""NEXA Assistant ("Jarvis"): a voice-first agent that acts on the user's NEXA data.

The app sends the spoken request plus the recent text transcript; the server
runs a Claude tool-use loop whose tools are scoped to the calling user (they
can only see and touch conversations the user is a member of) and returns the
reply to speak, plus a list of actions taken so the app can refresh its views.

The Anthropic API key stays on the server (``ANTHROPIC_API_KEY``); the app
never holds it.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from typing import Any, Literal

import anthropic
from anyio.from_thread import run as run_async
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..config import settings
from ..db import get_db
from ..models import Membership, Message, Task, TaskStatus, User
from ..realtime import manager
from ..schemas import TaskOut
from ..services import create_message, member_ids, message_event, require_member
from .inbox import inbox as build_inbox

router = APIRouter(prefix="/assistant", tags=["assistant"])

MAX_TOOL_ROUNDS = 8

SYSTEM_PROMPT = """You are Jarvis, the voice assistant built into NEXA, a messaging app \
that turns conversations into actions. The user talks to you hands-free, often while the \
app is in the background, and your reply is read aloud by text-to-speech.

How to reply:
- Speak naturally and briefly: one to three short sentences unless the user asks for detail.
- No markdown, bullet points, emoji, IDs or URLs; they sound wrong when spoken.
- Refer to chats and people by name, never by ID.
- Address the user as "sir" or "ma'am" only if they ask you to; otherwise just talk normally.

What you can do, using the tools:
- Check the inbox: who is waiting on a reply, unread chats, open tasks.
- Read recent messages in a chat and summarise them.
- Create tasks, list the user's tasks, and mark tasks done.
- Send a message on the user's behalf.

Rules:
- Before sending a message, be sure of both the chat and the wording. If the user dictated \
the exact text and named the chat, send it. If the recipient is ambiguous or you would be \
composing the text yourself, read back what you plan to send and ask for a yes first.
- Use the tools to answer questions about the user's chats and tasks; do not guess.
- If a request is outside what the tools can do (calls, alarms, web search, device \
settings), say plainly that you can't do that yet.
- Each user turn ends with a [context] line giving the current time; use it for relative \
dates like "tomorrow" or "Friday" and give due dates in ISO 8601 with a timezone."""


def _tool(name: str, description: str, properties: dict, required: list[str]) -> dict:
    return {
        "name": name,
        "description": description,
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": False,
        },
    }


TOOLS: list[dict] = [
    _tool(
        "get_inbox",
        "List the user's conversations in priority order: ones awaiting the user's reply "
        "first, then unread, then by recency. Includes each chat's id, title, members, the "
        "last message, unread count and how many open tasks the user has there.",
        {},
        [],
    ),
    _tool(
        "read_conversation",
        "Read the most recent messages in one conversation, oldest first.",
        {
            "conversation_id": {"type": "string"},
            "limit": {"type": "integer", "description": "How many messages, 1-50."},
        },
        ["conversation_id", "limit"],
    ),
    _tool(
        "send_message",
        "Send a text message as the user into a conversation they belong to.",
        {
            "conversation_id": {"type": "string"},
            "body": {"type": "string", "description": "The exact message text."},
        },
        ["conversation_id", "body"],
    ),
    _tool(
        "list_my_tasks",
        "List open tasks assigned to the user, soonest due first.",
        {},
        [],
    ),
    _tool(
        "create_task",
        "Create a task in a conversation. Assign it to the user unless they name another "
        "member of that conversation.",
        {
            "conversation_id": {"type": "string"},
            "title": {"type": "string"},
            "assignee_id": {
                "type": ["string", "null"],
                "description": "User id of a member; null means the requesting user.",
            },
            "due_at": {
                "type": ["string", "null"],
                "description": "ISO 8601 datetime with timezone, or null.",
            },
        },
        ["conversation_id", "title", "assignee_id", "due_at"],
    ),
    _tool(
        "complete_task",
        "Mark one of the user's tasks as done.",
        {"task_id": {"type": "string"}},
        ["task_id"],
    ),
]


# --------------------------------------------------------------------------- API


class Turn(BaseModel):
    role: Literal["user", "assistant"]
    text: str = Field(max_length=8000)


class AssistantRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    # Recent spoken transcript (text only), oldest first.
    history: list[Turn] = Field(default_factory=list, max_length=40)
    # The device's UTC offset, so "tomorrow at 9" lands in the user's local time.
    utc_offset_minutes: int = Field(default=0, ge=-14 * 60, le=14 * 60)


class AssistantAction(BaseModel):
    tool: str
    ok: bool
    summary: str


class AssistantReply(BaseModel):
    reply: str
    actions: list[AssistantAction]


_client: anthropic.Anthropic | None = None


def get_client() -> anthropic.Anthropic:
    """Lazily built so the API still starts (and tests run) without a key."""
    global _client
    if _client is None:
        _client = anthropic.Anthropic()
    return _client


@router.post("/chat", response_model=AssistantReply)
def chat(
    req: AssistantRequest,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    local_now = datetime.now(timezone(timedelta(minutes=req.utc_offset_minutes)))
    messages: list[dict[str, Any]] = [
        {"role": t.role, "content": t.text} for t in req.history if t.text.strip()
    ]
    # The API requires the conversation to start with a user turn and alternate.
    messages = _normalise(messages)
    messages.append(
        {
            "role": "user",
            "content": f"{req.text}\n\n[context] now={local_now.isoformat(timespec='minutes')} "
            f"user={user.display_name}",
        }
    )

    tools = _Tools(db, user)
    actions: list[AssistantAction] = []
    client = get_client()

    for _ in range(MAX_TOOL_ROUNDS):
        try:
            response = client.beta.messages.create(
                model=settings.assistant_model,
                max_tokens=16000,
                system=SYSTEM_PROMPT,
                tools=TOOLS,
                messages=messages,
                # Voice replies need to be quick; these requests are simple.
                output_config={"effort": "low"},
                betas=["server-side-fallback-2026-07-01"],
                fallbacks="default",
            )
        except anthropic.AuthenticationError as exc:
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE, "assistant is not configured"
            ) from exc
        except anthropic.RateLimitError as exc:
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE, "assistant is busy, try again shortly"
            ) from exc
        except anthropic.APIStatusError as exc:
            raise HTTPException(status.HTTP_502_BAD_GATEWAY, "assistant request failed") from exc
        except anthropic.APIConnectionError as exc:
            raise HTTPException(status.HTTP_502_BAD_GATEWAY, "assistant is unreachable") from exc

        if response.stop_reason == "refusal":
            return AssistantReply(reply="Sorry, I can't help with that one.", actions=actions)

        messages.append({"role": "assistant", "content": response.content})
        if response.stop_reason == "pause_turn":
            continue
        tool_uses = [b for b in response.content if b.type == "tool_use"]
        if response.stop_reason != "tool_use" or not tool_uses:
            text = " ".join(b.text for b in response.content if b.type == "text").strip()
            return AssistantReply(reply=text or "Done.", actions=actions)

        results = []
        for block in tool_uses:
            ok, content, summary = tools.run(block.name, block.input)
            actions.append(AssistantAction(tool=block.name, ok=ok, summary=summary))
            results.append(
                {
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": content,
                    **({} if ok else {"is_error": True}),
                }
            )
        messages.append({"role": "user", "content": results})

    return AssistantReply(
        reply="That took more steps than I can handle at once. Could you break it up?",
        actions=actions,
    )


def _normalise(turns: list[dict]) -> list[dict]:
    out: list[dict] = []
    for t in turns:
        if not out and t["role"] != "user":
            continue
        if out and out[-1]["role"] == t["role"]:
            out[-1] = {"role": t["role"], "content": out[-1]["content"] + "\n" + t["content"]}
        else:
            out.append(dict(t))
    # The new request is a user turn, so history must end on an assistant turn.
    if out and out[-1]["role"] == "user":
        out.pop()
    return out


# ------------------------------------------------------------------------- tools


class _ToolError(Exception):
    pass


class _Tools:
    """Tool implementations, all scoped to ``user``'s memberships."""

    def __init__(self, db: Session, user: User):
        self.db = db
        self.user = user

    def run(self, name: str, args: dict) -> tuple[bool, str, str]:
        """Return (ok, tool_result content, one-line summary for the app)."""
        fn = getattr(self, f"_t_{name}", None)
        if fn is None:
            return False, f"Unknown tool {name!r}.", f"unknown tool {name}"
        try:
            data, summary = fn(**args)
        except HTTPException as exc:
            return False, f"Error: {exc.detail}", f"{name} failed: {exc.detail}"
        except (_ToolError, TypeError, ValueError) as exc:
            return False, f"Error: {exc}", f"{name} failed: {exc}"
        return True, json.dumps(data, default=str), summary

    # -- helpers

    def _names(self, ids: list[str]) -> dict[str, str]:
        if not ids:
            return {}
        return dict(self.db.execute(select(User.id, User.display_name).where(User.id.in_(ids))).all())

    def _conv_title(self, conversation_id: str) -> str:
        m = require_member(self.db, conversation_id, self.user)
        conv = m.conversation
        if conv.title:
            return conv.title
        others = [x.user_id for x in conv.members if x.user_id != self.user.id]
        return ", ".join(self._names(others).values()) or "yourself"

    def _announce_task(self, task: Task, kind: str) -> None:
        run_async(
            manager.publish,
            member_ids(self.db, task.conversation_id),
            {"type": kind, "task": TaskOut.model_validate(task).model_dump(mode="json")},
        )

    # -- tools

    def _t_get_inbox(self):
        items = build_inbox(category=None, user=self.user, db=self.db)
        all_ids = {i for it in items for i in it.conversation.member_ids}
        names = self._names(list(all_ids))
        out = []
        for it in items[:20]:
            last = it.last_message
            out.append(
                {
                    "conversation_id": it.conversation.id,
                    "title": self._conv_title(it.conversation.id),
                    "members": [names.get(i, i) for i in it.conversation.member_ids],
                    "awaiting_my_reply": it.awaiting_my_reply,
                    "unread": it.unread_count,
                    "open_tasks_for_me": it.open_tasks_for_me,
                    "last_message": None
                    if last is None
                    else {
                        "from": names.get(last.sender_id, last.sender_id),
                        "text": last.body[:300],
                        "at": last.created_at,
                    },
                }
            )
        waiting = sum(1 for o in out if o["awaiting_my_reply"])
        return out, f"checked inbox ({waiting} awaiting reply)"

    def _t_read_conversation(self, conversation_id: str, limit: int):
        title = self._conv_title(conversation_id)
        limit = max(1, min(int(limit), 50))
        msgs = list(
            self.db.scalars(
                select(Message)
                .where(Message.conversation_id == conversation_id)
                .order_by(Message.created_at.desc())
                .limit(limit)
            )
        )[::-1]
        names = self._names(list({m.sender_id for m in msgs}))
        data = {
            "title": title,
            "messages": [
                {
                    "from": "me" if m.sender_id == self.user.id else names.get(m.sender_id),
                    "text": m.body,
                    "at": m.created_at,
                }
                for m in msgs
            ],
        }
        return data, f"read {len(msgs)} messages in {title}"

    def _t_send_message(self, conversation_id: str, body: str):
        body = body.strip()
        if not body:
            raise _ToolError("message body is empty")
        title = self._conv_title(conversation_id)
        msg, _ = create_message(self.db, self.user, conversation_id, body, None)
        run_async(manager.publish, member_ids(self.db, conversation_id), message_event(msg))
        return {"sent": True, "message_id": msg.id}, f"sent a message to {title}"

    def _t_list_my_tasks(self):
        tasks = list(
            self.db.scalars(
                select(Task)
                .where(Task.assignee_id == self.user.id, Task.status == TaskStatus.open)
                .order_by(Task.due_at.is_(None), Task.due_at, Task.created_at)
                .limit(30)
            )
        )
        data = [
            {
                "task_id": t.id,
                "title": t.title,
                "due_at": t.due_at,
                "chat": self._conv_title(t.conversation_id),
            }
            for t in tasks
        ]
        return data, f"listed {len(tasks)} open tasks"

    def _t_create_task(
        self, conversation_id: str, title: str, assignee_id: str | None, due_at: str | None
    ):
        chat_title = self._conv_title(conversation_id)
        assignee = assignee_id or self.user.id
        if assignee not in member_ids(self.db, conversation_id):
            raise _ToolError("assignee is not a member of that conversation")
        due = None
        if due_at:
            due = datetime.fromisoformat(due_at)
            if due.tzinfo is None:
                raise _ToolError("due_at needs a timezone offset")
        title = title.strip()[:300]
        if not title:
            raise _ToolError("task title is empty")
        task = Task(
            conversation_id=conversation_id,
            title=title,
            assignee_id=assignee,
            due_at=due,
            created_by=self.user.id,
        )
        self.db.add(task)
        self.db.commit()
        self._announce_task(task, "task.created")
        return {"task_id": task.id, "title": task.title}, f"created task “{title}” in {chat_title}"

    def _t_complete_task(self, task_id: str):
        task = self.db.get(Task, task_id)
        if task is None or self.db.get(Membership, (task.conversation_id, self.user.id)) is None:
            raise _ToolError("task not found")
        task.status = TaskStatus.done
        self.db.commit()
        self._announce_task(task, "task.updated")
        return {"done": True}, f"completed task “{task.title}”"
