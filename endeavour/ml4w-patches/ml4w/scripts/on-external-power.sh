#!/usr/bin/env bash
# Exit 0 when the laptop is on external power (AC adapter or USB-C PD).
set -euo pipefail

for ps in /sys/class/power_supply/*; do
    [[ -f "$ps/online" && -f "$ps/type" ]] || continue
    type=$(<"$ps/type")
    online=$(<"$ps/online")
    case "$type" in
        Mains | USB)
            [[ "$online" == 1 ]] && exit 0
            ;;
    esac
done

exit 1
