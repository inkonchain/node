#!/bin/sh
set -eu

if [ -z "$(ls -A /data)" ]; then
    echo "/data is empty, running geth init..."
    echo "🟢 running geth init"
    ./geth init --datadir="/data" /config/sepolia/genesis-l2.json
else
    echo "🟡 geth data directory is not empty, skipping geth init"
    echo "🟡 if you want to reset from a snapshot, check out instructions in the readme"
fi

exec ./geth
