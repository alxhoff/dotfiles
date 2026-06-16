#!/usr/bin/env bash
# Dunst with dotfiles timeouts; keep mako (systemd) from owning notifications.
set -euo pipefail

systemctl --user stop mako.service 2>/dev/null || true
systemctl --user mask mako.service 2>/dev/null || true
killall mako 2>/dev/null || true

if pgrep -x dunst >/dev/null; then
	exit 0
fi

exec dunst
