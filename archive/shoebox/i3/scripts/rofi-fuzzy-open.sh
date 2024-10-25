#!/bin/bash
FILE=$(fd . | rofi -dmenu -i -p "Open file")
[[ -n "$FILE" ]] && xdg-open "$FILE"
