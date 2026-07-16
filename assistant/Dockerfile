FROM python:3.11-slim

WORKDIR /app

COPY assistant/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY assistant/ .
# Corpus RAG (mounted read-only in compose; also baked for prod image)
COPY docs/ /corpus/docs/
COPY contracts/ /corpus/contracts/
COPY README.md /corpus/README.md
COPY .specify/specs/factoria/2_spec.md /corpus/.specify/specs/factoria/2_spec.md

ENV CORPUS_ROOT=/corpus
EXPOSE 8001

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8001"]
