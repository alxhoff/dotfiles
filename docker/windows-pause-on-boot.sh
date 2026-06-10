#!/usr/bin/env bash
# Pause the Windows VM after Docker auto-starts it on boot (restart: unless-stopped).
set -euo pipefail

CONTAINER=windows

command -v docker >/dev/null || exit 0
systemctl is-active --quiet docker 2>/dev/null || exit 0

for _ in $(seq 1 45); do
    status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo missing)
    case "$status" in
        running)
            docker pause "$CONTAINER"
            exit 0
            ;;
        paused | exited | missing)
            exit 0
            ;;
    esac
    sleep 2
done
