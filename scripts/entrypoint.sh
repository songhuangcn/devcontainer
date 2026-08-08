#!/bin/sh

openclaw gateway --allow-unconfigured --bind lan --port 18789 &
exec opencode web --hostname 0.0.0.0 --port "${OPENCODE_PORT:-4096}"
