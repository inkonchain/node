#!/bin/sh
set -eu

# wait until op-geth is available
while ! nc -z op-geth 8551; do
    echo "🕚 waiting for op-geth to be available..."
    sleep 2
done

exec ./op-node
