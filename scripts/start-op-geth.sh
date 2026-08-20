#!/bin/sh
set -eu

# Wait for the Bedrock flag for this network to be set.
echo "Waiting for Bedrock node to initialize..."
while [ ! -f /shared/initialized.txt ]; do
  sleep 1
done

# SECURITY FIX: Accept one explicit flag only so environment input cannot be split into an
# arbitrary argument list or expanded as a pathname (prevents shell argument injection).
if [ -n "${EXTENDED_ARG:-}" ]; then
  case "$EXTENDED_ARG" in
    --*=*) set -- "$EXTENDED_ARG" "$@" ;;
    *)
      echo "EXTENDED_ARG must contain one --flag=value argument" >&2
      exit 1
      ;;
  esac
fi

# Override Holocene when explicitly requested.
if [ -n "${OVERRIDE_HOLOCENE:-}" ]; then
  set -- "--override.holocene=$OVERRIDE_HOLOCENE" "$@"
fi

# SECURITY FIX: Start op-geth with the public HTTP API restricted to non-sensitive methods.
# Wildcard CORS and vhosts are replaced with explicit local defaults.
exec geth \
  --op-network="$NETWORK_NAME" \
  --datadir="$BEDROCK_DATADIR" \
  --http \
  --http.corsdomain="${OP_GETH__HTTP_CORS_DOMAIN:-http://localhost}" \
  --http.vhosts="${OP_GETH__HTTP_VHOSTS:-localhost,127.0.0.1,op-geth}" \
  --http.addr=0.0.0.0 \
  --http.port=8545 \
  --http.api=eth,net,web3 \
  --metrics \
  --metrics.influxdb \
  --metrics.influxdb.endpoint=http://influxdb:8086 \
  --metrics.influxdb.database=opgeth \
  --authrpc.vhosts="${OP_GETH__AUTHRPC_VHOSTS:-localhost,127.0.0.1,op-geth,op-node}" \
  --authrpc.addr=0.0.0.0 \
  --authrpc.port=8551 \
  --authrpc.jwtsecret=/shared/jwt.txt \
  --rollup.sequencerhttp="$BEDROCK_SEQUENCER_HTTP" \
  --rollup.disabletxpoolgossip=true \
  --port="${PORT__OP_GETH_P2P:-39393}" \
  --discovery.port="${PORT__OP_GETH_P2P:-39393}" \
  --db.engine=pebble \
  --state.scheme=hash \
  --txlookuplimit=0 \
  --history.state=0 \
  --history.transactions=0 \
  --txpool.pricebump=10 \
  --txpool.lifetime=12h0m0s \
  --rpc.txfeecap=4 \
  --rpc.evmtimeout=0 \
  --maxpeers=0 \
  --nodiscover \
  --gpo.percentile=60 \
  --verbosity=3 \
  --syncmode="full" \
  --gcmode="$NODE_TYPE" \
  "$@"