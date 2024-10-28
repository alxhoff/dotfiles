#!/bin/bash
file=$(find . -name "*$1*.c" | fzf)
if [ -n "$file" ]; then
    exec vim "$file"
fi
