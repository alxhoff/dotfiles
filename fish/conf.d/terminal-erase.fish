# Host terminal (kitty, etc.): erase char for local line editing and SSH PTY forwarding.
# OpenSSH copies the local TTY erase setting to the remote session on connect.
if status is-interactive && isatty stdin
    if command -v stty >/dev/null
        stty erase '^?' 2>/dev/null
    end
end
