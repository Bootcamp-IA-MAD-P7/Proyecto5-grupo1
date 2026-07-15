FROM python:3.11-slim

WORKDIR /app

# Build context: repository root (see docker-compose.yml / CI)
COPY inference/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY inference/ .
COPY contracts/ /contracts/

EXPOSE 8000

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
