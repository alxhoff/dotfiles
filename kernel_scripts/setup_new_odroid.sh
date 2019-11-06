#!/bin/bash
# this script provides a new odroid distribution with the necessary RCS tweaks
# e.g. kernel, systemui modifications, etc.

./install_systemui.sh
./install_libs.sh
cd ~/PowerLogger
make android install
