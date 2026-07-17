"""BM25 RAG with role-scoped corpora (end users ≠ architecture docs)."""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from pathlib import Path

from rank_bm25 import BM25Okapi

from api import config

log = logging.getLogger("assistant.rag")

_CHUNK_SIZE = 900
_CHUNK_OVERLAP = 120

# End-user help + admin ops live under docs/assistant/.
# Technical corpus (contracts / README / spec) is IT_ADMIN only.
_INCLUDE_GLOBS = (
    "docs/assistant/**/*.md",
    "contracts/**/*.md",
    "README.md",
    ".specify/specs/factoria/2_spec.md",
)

_ALL_ROLES = frozenset({"IT_ADMIN", "CAREGIVER", "MONITORED"})


@dataclass(frozen=True)
class Chunk:
    source: str
    text: str
    roles: frozenset[str]


class DocIndex:
    def __init__(self) -> None:
        self.chunks: list[Chunk] = []

    def build(self, root: Path | None = None) -> int:
        root = root or config.CORPUS_ROOT
        chunks: list[Chunk] = []
        for pattern in _INCLUDE_GLOBS:
            for path in root.glob(pattern):
                if not path.is_file():
                    continue
                # Never index daily notes / internal plans even if nested under docs/.
                rel = str(path.relative_to(root)).replace("\\", "/")
                if "/daily/" in f"/{rel}" or "/superpowers/" in f"/{rel}":
                    continue
                try:
                    text = path.read_text(encoding="utf-8", errors="ignore")
                except OSError as exc:
                    log.warning("skip %s: %s", path, exc)
                    continue
                roles = _roles_for_source(rel)
                for piece in _split_markdown(text):
                    if len(piece.strip()) < 40:
                        continue
                    chunks.append(Chunk(source=rel, text=piece.strip(), roles=roles))

        self.chunks = chunks
        log.info("RAG index: %d chunks from %s", len(chunks), root)
        return len(chunks)

    def search(self, query: str, k: int = 4, role: str = "MONITORED") -> list[dict]:
        role_key = (role or "MONITORED").upper()
        if role_key not in _ALL_ROLES:
            role_key = "MONITORED"

        eligible = [c for c in self.chunks if role_key in c.roles]
        if not eligible:
            return []

        tokens = [_tokenize(c.text) for c in eligible]
        bm25 = BM25Okapi(tokens)
        scores = bm25.get_scores(_tokenize(query))
        ranked = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
        out: list[dict] = []
        seen: set[str] = set()
        for i in ranked:
            if scores[i] <= 0:
                break
            chunk = eligible[i]
            key = f"{chunk.source}:{chunk.text[:80]}"
            if key in seen:
                continue
            seen.add(key)
            out.append(
                {
                    "source": chunk.source,
                    "snippet": chunk.text[:600],
                    "score": float(scores[i]),
                }
            )
            if len(out) >= k:
                break
        return out


def _roles_for_source(rel: str) -> frozenset[str]:
    if rel.startswith("docs/assistant/shared/"):
        return _ALL_ROLES
    if rel.startswith("docs/assistant/monitored/"):
        return frozenset({"MONITORED", "IT_ADMIN"})
    if rel.startswith("docs/assistant/caregiver/"):
        return frozenset({"CAREGIVER", "IT_ADMIN"})
    if rel.startswith("docs/assistant/it_admin/"):
        return frozenset({"IT_ADMIN"})
    # contracts, README, spec, any other matched path → admin only
    return frozenset({"IT_ADMIN"})


def _tokenize(text: str) -> list[str]:
    return re.findall(r"[a-zA-ZáéíóúñÁÉÍÓÚÑ0-9_./-]{2,}", text.lower())


def _split_markdown(text: str) -> list[str]:
    parts = re.split(r"\n(?=#{1,3}\s)", text)
    chunks: list[str] = []
    for part in parts:
        part = part.strip()
        if not part:
            continue
        if len(part) <= _CHUNK_SIZE:
            chunks.append(part)
            continue
        start = 0
        while start < len(part):
            end = min(start + _CHUNK_SIZE, len(part))
            chunks.append(part[start:end])
            if end >= len(part):
                break
            start = max(0, end - _CHUNK_OVERLAP)
    return chunks


INDEX = DocIndex()
