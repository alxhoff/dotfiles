#!/bin/bash

TID=$(xinput list | grep -iPo 'touchpad.*id=\K\d+')

xinput disable "$TID"
xinput enable "$TID"
