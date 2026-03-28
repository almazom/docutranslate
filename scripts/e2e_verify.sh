#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

read_env_value() {
    local key="$1"
    local env_file="${2:-$ROOT_DIR/.env}"
    if [[ -f "$env_file" ]]; then
        awk -F= -v key="$key" '$1 == key { print substr($0, index($0, $2)); exit }' "$env_file"
    fi
}

ensure_local_stack() {
    local health_url="$1"
    case "$E2E_BASE_URL" in
        https://127.0.0.1:*|https://localhost:*|http://127.0.0.1:*|http://localhost:*)
            if [[ "${E2E_REBUILD_LOCAL:-1}" == "1" ]]; then
                docker compose up -d --build
            elif curl -kfsS "$health_url" >/dev/null 2>&1; then
                return 0
            else
                docker compose up -d
            fi
            ;;
        *)
            if curl -kfsS "$health_url" >/dev/null 2>&1; then
                return 0
            fi
            echo "Health check failed for remote target: $E2E_BASE_URL" >&2
            return 1
            ;;
    esac

    for _ in {1..60}; do
        if curl -kfsS "$health_url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done

    echo "Timed out waiting for $health_url" >&2
    return 1
}

DEFAULT_HTTPS_PORT="$(read_env_value DOCUTRANSLATE_HTTPS_PORT)"
DEFAULT_HTTPS_PORT="${DEFAULT_HTTPS_PORT:-443}"
export E2E_BASE_URL="${E2E_BASE_URL:-https://127.0.0.1:${DEFAULT_HTTPS_PORT}}"
export CI="${CI:-1}"

ensure_local_stack "${E2E_BASE_URL%/}/health"

if [[ ! -d node_modules ]]; then
    npm install
fi

python tests/e2e/fixtures/build_samples.py
npx playwright install chromium >/dev/null

repeat_count="${E2E_REPEAT_COUNT:-1}"
grep_args=()

if [[ -z "${E2E_TRANSLATION_API_KEY:-}" || -z "${E2E_TRANSLATION_MODEL_ID:-}" ]]; then
    grep_args+=(--grep-invert @real-translation)
fi

for run_index in $(seq 1 "$repeat_count"); do
    echo "E2E run ${run_index}/${repeat_count}"
    npx bddgen
    npx playwright test "${grep_args[@]}" "$@"
done
