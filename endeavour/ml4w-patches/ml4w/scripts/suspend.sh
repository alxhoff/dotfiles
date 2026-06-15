#!/usr/bin/env bash
# Manual suspend (power menu / wlogout). Always suspends, including on AC.
set -euo pipefail
exec systemctl suspend
