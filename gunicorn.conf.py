import os


workers = int(os.getenv("DOCUTRANSLATE_GUNICORN_WORKERS", "1"))
worker_class = "uvicorn.workers.UvicornWorker"
bind = f"0.0.0.0:{os.getenv('DOCUTRANSLATE_PORT', '8010')}"
timeout = int(os.getenv("DOCUTRANSLATE_GUNICORN_TIMEOUT", "300"))
graceful_timeout = int(os.getenv("DOCUTRANSLATE_GUNICORN_GRACEFUL_TIMEOUT", "120"))
keepalive = int(os.getenv("DOCUTRANSLATE_GUNICORN_KEEPALIVE", "5"))
