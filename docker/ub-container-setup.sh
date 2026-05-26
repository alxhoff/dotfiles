#!/usr/bin/env bash
# Run inside Ubuntu dev container via: docker exec -i … env UB_*=… bash -s < this-file
set -euo pipefail

UB_USER=${UB_USER:?UB_USER required}
UB_UID=${UB_UID:?UB_UID required}
UB_GID=${UB_GID:?UB_GID required}
UB_HOME=${UB_HOME:?UB_HOME required}
UB_HOST=${UB_HOST:?UB_HOST required}

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y sudo fish xauth x11-apps

grep -q "$UB_HOST" /etc/hosts || echo "127.0.0.1 $UB_HOST" >> /etc/hosts

if getent passwd "$UB_USER" >/dev/null; then
    echo "User $UB_USER already exists."
    exit 0
fi

existing_user=$(getent passwd "$UB_UID" | cut -d: -f1 || true)
existing_group=$(getent group "$UB_GID" | cut -d: -f1 || true)

if [[ -n "$existing_user" ]]; then
    if [[ -n "$existing_group" && "$existing_group" != "$UB_USER" ]]; then
        groupmod -n "$UB_USER" "$existing_group"
    fi
    usermod -l "$UB_USER" -d "$UB_HOME" "$existing_user"
    usermod -g "$UB_USER" "$UB_USER"
else
    if getent group "$UB_GID" >/dev/null; then
        groupmod -n "$UB_USER" "$(getent group "$UB_GID" | cut -d: -f1)"
    else
        groupadd -g "$UB_GID" "$UB_USER"
    fi
    useradd -u "$UB_UID" -g "$UB_GID" -d "$UB_HOME" -s /usr/bin/fish --no-create-home "$UB_USER"
fi

usermod -aG sudo "$UB_USER"
echo "$UB_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$UB_USER"
chmod 0440 "/etc/sudoers.d/$UB_USER"

echo "User $UB_USER ready."
