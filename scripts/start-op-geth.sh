#!/bin/sh
set -e

# Wait for the Bedrock flag for this network to be set.
echo "Waiting for Bedrock node to initialize..."
while [ ! -f /shared/initialized.txt ]; do
  sleep 1
done

# Keep the container listener reachable through Docker while restricting browser and Host-header access by default.
HTTP_CORS_DOMAIN="${OP_GETH_HTTP_CORS_DOMAIN:-http://localhost,http://127.0.0.1}"
HTTP_VHOSTS="${OP_GETH_HTTP_VHOSTS:-op-geth,localhost,127.0.0.1}"
HTTP_API="${OP_GETH_HTTP_API:-eth,net,web3}"
AUTHRPC_VHOSTS="${OP_GETH_AUTHRPC_VHOSTS:-op-geth,localhost,127.0.0.1}"
INFLUXDB_USERNAME="${INFLUXDB_WRITE_USER:?Set INFLUXDB_WRITE_USER in .env}"
INFLUXDB_PASSWORD="${INFLUXDB_WRITE_USER_PASSWORD:?Set INFLUXDB_WRITE_USER_PASSWORD in .env}"

# Override Holocene.
if [ -n "$OVERRIDE_HOLOCENE" ]; then
  EXTENDED_ARG="$EXTENDED_ARG --override.holocene=$OVERRIDE_HOLOCENE"
fi

# Start op-geth.
exec geth \
  --op-network="$NETWORK_NAME" \
  --datadir="$BEDROCK_DATADIR" \
  --http \
  --http.corsdomain="$HTTP_CORS_DOMAIN" \
  --http.vhosts="$HTTP_VHOSTS" \
  --http.addr=0.0.0.0 \
  --http.port=8545 \
  --http.api="$HTTP_API" \
  --metrics \
  --metrics.influxdb \
  --metrics.influxdb.endpoint=http://influxdb:8086 \
  --metrics.influxdb.database=opgeth \
  --metrics.influxdb.username="$INFLUXDB_USERNAME" \
  --metrics.influxdb.password="$INFLUXDB_PASSWORD" \
  --authrpc.vhosts="$AUTHRPC_VHOSTS" \
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
  $EXTENDED_ARG "$@"
