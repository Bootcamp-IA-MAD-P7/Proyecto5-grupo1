"""Acceso a PostgreSQL local (docker-compose). Producción → AWS RDS."""

from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Any

import psycopg2
from psycopg2.extras import RealDictCursor

DATABASE_URL = os.environ.get("DATABASE_URL", "")


def postgres_enabled() -> bool:
    return bool(DATABASE_URL)


@contextmanager
def get_connection():
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL no configurada")
    conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def fetch_latest_app_version() -> dict[str, Any] | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT version_code, version_name, apk_url, release_notes,
                       min_supported_version_code
                FROM app_versions
                ORDER BY version_code DESC
                LIMIT 1
                """
            )
            return cur.fetchone()


def insert_app_version(row: dict[str, Any]) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO app_versions (
                    version_code, version_name, apk_url,
                    release_notes, min_supported_version_code
                ) VALUES (%(version_code)s, %(version_name)s, %(apk_url)s,
                          %(release_notes)s, %(min_supported_version_code)s)
                ON CONFLICT (version_code) DO UPDATE SET
                    version_name = EXCLUDED.version_name,
                    apk_url = EXCLUDED.apk_url,
                    release_notes = EXCLUDED.release_notes,
                    min_supported_version_code = EXCLUDED.min_supported_version_code
                """,
                row,
            )
