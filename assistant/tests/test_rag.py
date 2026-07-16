"""Unit tests for BM25 RAG index (no Groq needed)."""

from pathlib import Path

from api.rag import DocIndex


def test_index_builds_and_searches_readme():
    root = Path(__file__).resolve().parents[2]
    idx = DocIndex()
    n = idx.build(root)
    assert n > 0
    hits = idx.search("detección de caídas SentiLife", k=3)
    assert hits
    assert any("README" in h["source"] or "docs/" in h["source"] for h in hits)
