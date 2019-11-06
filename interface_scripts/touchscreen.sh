#!/bin/bash
TP=$(xinput list | grep -iPo 'touchpad.*id=\K\d+')
STY=$(xinput list | grep -iPo 'stylus.*id=\K\d+')
ERA=$(xinput list | grep -iPo 'eraser.*id=\K\d+')

xinput --map-to-output "$TP" eDP1
xinput --map-to-output "$STY" eDP1
xinput --map-to-output "$ERA" eDP1

