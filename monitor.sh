#!/bin/bash
set -e

cd /opt/reposerver
source ./venv/bin/activate
python monitor.py "$@"
