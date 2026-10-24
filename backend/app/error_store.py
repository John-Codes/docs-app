"""Storage for client error reports: MongoDB when configured, memory otherwise.

MongoDB is the durable sink. The in-memory ring buffer exists so a report is
never lost just because `MONGODB_URI` is unset — a missing database must not
turn "we cannot tell what broke on that iPhone" back into the old silence.
"""

from __future__ import annotations

import asyncio
from collections import deque
from datetime import datetime, timezone

from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import DESCENDING, IndexModel

from app.config import Settings

_RING_SIZE = 500
_INSERT_TIMEOUT = 3.0


class ClientErrorStore:
    """Holds client error reports and keeps the collection indexed."""

    def __init__(self, settings: Settings) -> None:
        self._client: AsyncIOMotorClient | None = None
        self._collection = None
        self._ring: deque[dict] = deque(maxlen=_RING_SIZE)
        self._lock = asyncio.Lock()
        if settings.mongodb_uri:
            self._client = AsyncIOMotorClient(
                settings.mongodb_uri,
                serverSelectionTimeoutMS=5000,
                connectTimeoutMS=5000,
                socketTimeoutMS=10000,
            )
            self._collection = self._client[settings.mongodb_db]["client_errors"]

    @property
    def persistent(self) -> bool:
        """True when reports are being written to MongoDB."""
        return self._collection is not None

    async def start(self) -> None:
        """Verify the connection and create indexes. Never raises."""
        if self._collection is None:
            return
        try:
            await asyncio.wait_for(self._client.admin.command("ping"), _INSERT_TIMEOUT)
            await self._collection.create_indexes(
                [
                    IndexModel([("created_at", DESCENDING)]),
                    IndexModel([("install_id", ASCENDING), ("created_at", DESCENDING)]),
                    IndexModel([("stage", ASCENDING), ("created_at", DESCENDING)]),
                ]
            )
        except Exception as failure:  # noqa: BLE001 - a missing DB is not fatal
            print(f"[errors] MongoDB unavailable, keeping memory-only: {failure}")
            self._collection = None

    def close(self) -> None:
        if self._client is not None:
            self._client.close()

    async def add(self, report: dict) -> dict:
        """Store one report. Returns it with an id and a timestamp."""
        record = dict(report)
        record.setdefault("created_at", datetime.now(timezone.utc))
        async with self._lock:
            self._ring.appendleft(record)
            if self._collection is not None:
                try:
                    await asyncio.wait_for(
                        self._collection.insert_one(dict(record)), _INSERT_TIMEOUT
                    )
                except Exception as failure:  # noqa: BLE001 - never break the caller
                    print(f"[errors] MongoDB write failed: {failure}")
        return record

    async def recent(self, limit: int = 200) -> list[dict]:
        """The newest reports, newest first."""
        if self._collection is not None:
            try:
                cursor = self._collection.find().sort("created_at", DESCENDING).limit(limit)
                docs = await asyncio.wait_for(cursor.to_list(length=limit), _INSERT_TIMEOUT)
                return [_plain(doc) for doc in docs]
            except Exception as failure:  # noqa: BLE001
                print(f"[errors] MongoDB read failed, serving memory: {failure}")
        async with self._lock:
            return list(self._ring)[:limit]


def _plain(document: dict) -> dict:
    """Make a Mongo document JSON-safe by stringifying ``_id``."""
    out = dict(document)
    out.pop("_id", None)
    created = out.get("created_at")
    if isinstance(created, datetime):
        out["created_at"] = created.isoformat()
    return out
