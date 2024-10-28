#!/bin/bash
FILE=$(zenity --file-selection --title="Select a file to open")
[[ -n "$FILE" ]] && xdg-open "$FILE"
