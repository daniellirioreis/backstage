#!/bin/bash
set -e

# Remove server.pid que pode travar o boot após crash
rm -f /app/tmp/pids/server.pid

exec "$@"
