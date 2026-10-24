"""Storage for client error reports: MongoDB when configured, memory otherwise.

MongoDB is the durable sink (reports survive a redeploy and can be analysed
in bulk). The in-memory ring exists so a report is never lost just because
``MONGODB_URI`` is unset — a missing database must not turn "we cannot tell
what broke on that iPhone" back into silence.
"""

from __future__ import annotations

import asyncio
from collections import deque
from datetime import datetime, timezone

from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ASCENDING, DESCENDING, IndexModel

from app.config import Settings

_RING_SIZE = 500
_TIMEOUT = 3.0


class MemoryErrorStore:
    """The always-available fallback: newest reports in RAM."""

    persistent = False

    def __init__(self) -> None:
        self._ring: deque[dict] = deque(maxlen=_RING_SIZE)

    async def add(self, record: dict) -> None:
        entry = dict(record)
        entry.setdefault(
            "created_at", datetime.now(timezone.utc).isoformat()
        )
        self._ring.appendleft(entry)

    async def recent(self, limit: int) -> list[dict]:
        return list(self._ring)[:limit]


class ClientErrorStore(MemoryErrorStore):
    """Writes through to MongoDB, mirroring into the memory ring."""

    persistent = True

    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self._client = AsyncIOMotorClient(
            settings.mongodb_uri,
            serverSelectionTimeoutMS=5000,
            connectTimeoutMS=5000,
            socketTimeoutMS=10000,
        )
        self._collection = self._client[settings.mongodb_db]["client_errors"]

    async def add(self, record: dict) -> None:
        await super().add(record)
        stored = dict(record)
        stored.setdefault("created_at", datetime.now(timezone.utc))
        try:
            await asyncio.wait_for(
                self._collection.insert_one(stored), _TIMEOUT
            )
        except Exception as failure:  # noqa: BLE001 - never break the caller
            print(f"[client-logs] MongoDB write failed: {failure}")

    async def recent(self, limit: int) -> list[dict]:
        try:
            cursor = (
                self._collection.find()
                .sort("created_at", DESCENDING)
                .limit(limit)
            )
            docs = await asyncio.wait_for(
                cursor.to_list(length=limit), _TIMEOUT
            )
            return [_plain(doc) for doc in docs]
        except Exception as failure:  # noqa: BLE001
            print(f"[client-logs] MongoDB read failed, serving memory: {failure}")
            return await super().recent(limit)

    async def start(self) -> None:
        """Verify the connection and create indexes. Never raises."""
        try:
            await asyncio.wait_for(
                self._client.admin.command("ping"), _TIMEOUT
            )
            await self._collection.create_indexes(
                [
                    IndexModel([("created_at", DESCENDING)]),
                    IndexModel([("event", ASCENDING), ("created_at", DESCENDING)]),
                ]
            )
        except Exception as failure:  # noqa: BLE001
            print(f"[client-logs] MongoDB unavailable: {failure}")

    def close(self) -> None:
        """Close the connection pool."""
        self._client.close()


def _plain(document: dict) -> dict:
    """Make a Mongo document JSON-safe by stringifying ``_id``."""
    out = dict(document)
    out.pop("_id", None)
    created = out.get("created_at")
    if isinstance(created, datetime):
        out["created_at"] = created.isoformat()
    return out
