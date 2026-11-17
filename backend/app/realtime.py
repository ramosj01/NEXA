"""WebSocket fan-out.

Single-process connection registry. To run more than one API instance, put a
pub/sub layer (e.g. Redis or Postgres LISTEN/NOTIFY) behind ``publish``.
"""

import asyncio
from collections import defaultdict
from typing import Any

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._sockets: dict[str, set[WebSocket]] = defaultdict(set)

    async def connect(self, user_id: str, ws: WebSocket) -> None:
        await ws.accept()
        self._sockets[user_id].add(ws)

    def disconnect(self, user_id: str, ws: WebSocket) -> None:
        self._sockets[user_id].discard(ws)
        if not self._sockets[user_id]:
            self._sockets.pop(user_id, None)

    def is_online(self, user_id: str) -> bool:
        return user_id in self._sockets

    async def publish(self, user_ids: list[str], event: dict[str, Any]) -> None:
        targets = [ws for uid in user_ids for ws in list(self._sockets.get(uid, ()))]
        results = await asyncio.gather(
            *(ws.send_json(event) for ws in targets), return_exceptions=True
        )
        for ws, result in zip(targets, results):
            if isinstance(result, Exception):
                for uid, socks in list(self._sockets.items()):
                    if ws in socks:
                        self.disconnect(uid, ws)


manager = ConnectionManager()
