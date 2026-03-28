FROM python:3.11-slim AS builder
LABEL authors="xunbu"

ENV UV_HTTP_TIMEOUT=300 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /src

RUN apt-get update && apt-get install -y --no-install-recommends \
    pandoc \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

COPY pyproject.toml README.md /src/
COPY docutranslate /src/docutranslate

RUN uv venv /opt/venv \
    && uv pip install --python /opt/venv/bin/python /src

FROM python:3.11-slim AS runtime

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DOCUTRANSLATE_PORT=8010

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    pandoc \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system docutranslate \
    && useradd --system --gid docutranslate --home-dir /app --create-home docutranslate

COPY --from=builder /opt/venv /opt/venv

RUN mkdir -p /app/output /app/data/tasks \
    && chown -R docutranslate:docutranslate /app

VOLUME ["/app/output", "/app/data/tasks"]

USER docutranslate

EXPOSE 8010

CMD ["docutranslate", "-i", "--host", "0.0.0.0", "-p", "8010"]
