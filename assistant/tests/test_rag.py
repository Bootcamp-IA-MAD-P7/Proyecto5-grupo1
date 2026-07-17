"""Unit tests for BM25 RAG index (no Groq needed)."""

from pathlib import Path

from api.rag import DocIndex


def test_index_builds_role_scoped_corpus():
    root = Path(__file__).resolve().parents[2]
    idx = DocIndex()
    n = idx.build(root)
    assert n > 0

    monitored = idx.search("consentimiento emparejamiento sensores", k=3, role="MONITORED")
    assert monitored
    assert all(
        h["source"].startswith("docs/assistant/monitored/")
        or h["source"].startswith("docs/assistant/shared/")
        for h in monitored
    )
    assert not any(
        "README" in h["source"] or h["source"].startswith("contracts/") or ".specify/" in h["source"]
        for h in monitored
    )

    caregiver = idx.search("alertas notificaciones personas", k=3, role="CAREGIVER")
    assert caregiver
    assert all(
        h["source"].startswith("docs/assistant/caregiver/")
        or h["source"].startswith("docs/assistant/shared/")
        for h in caregiver
    )

    admin = idx.search("reentrenamiento drift registry", k=5, role="IT_ADMIN")
    assert admin
    # Admin may see ops guide and/or technical corpus.
    assert any(
        h["source"].startswith("docs/assistant/it_admin/")
        or h["source"].startswith("contracts/")
        or "README" in h["source"]
        or ".specify/" in h["source"]
        for h in admin
    )


def test_end_users_never_get_architecture_hits_for_build_query():
    root = Path(__file__).resolve().parents[2]
    idx = DocIndex()
    idx.build(root)
    hits = idx.search("docker compose CI arquitectura stack", k=5, role="MONITORED")
    for h in hits:
        assert not h["source"].startswith("contracts/")
        assert "README" not in h["source"]
        assert ".specify/" not in h["source"]
