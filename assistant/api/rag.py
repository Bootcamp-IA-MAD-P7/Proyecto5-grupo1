"""BM25 RAG over project markdown (docs/, contracts/, README, spec)."""

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

_INCLUDE_GLOBS = (
    "docs/**/*.md",
    "contracts/**/*.md",
    "README.md",
    ".specify/specs/factoria/2_spec.md",
)


@dataclass(frozen=True)
class Chunk:
    source: str
    text: str


class DocIndex:
    def __init__(self) -> None:
        self.chunks: list[Chunk] = []
        self._bm25: BM25Okapi | None = None
        self._tokens: list[list[str]] = []

    def build(self, root: Path | None = None) -> int:
        root = root or config.CORPUS_ROOT
        chunks: list[Chunk] = []
        for pattern in _INCLUDE_GLOBS:
            for path in root.glob(pattern):
                if not path.is_file():
                    continue
                try:
                    text = path.read_text(encoding="utf-8", errors="ignore")
                except OSError as exc:
                    log.warning("skip %s: %s", path, exc)
                    continue
                rel = str(path.relative_to(root)).replace("\\", "/")
                for piece in _split_markdown(text):
                    if len(piece.strip()) < 40:
                        continue
                    chunks.append(Chunk(source=rel, text=piece.strip()))

        self.chunks = chunks
        self._tokens = [_tokenize(c.text) for c in chunks]
        self._bm25 = BM25Okapi(self._tokens) if chunks else None
        log.info("RAG index: %d chunks from %s", len(chunks), root)
        return len(chunks)

    def search(self, query: str, k: int = 4) -> list[dict]:
        if not self.chunks or self._bm25 is None:
            return []
        scores = self._bm25.get_scores(_tokenize(query))
        ranked = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
        out: list[dict] = []
        seen: set[str] = set()
        for i in ranked:
            if scores[i] <= 0:
                break
            chunk = self.chunks[i]
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
