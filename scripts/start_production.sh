#!/bin/sh
set -eu

cd /app
exec gunicorn -c gunicorn.conf.py docutranslate.app:app
