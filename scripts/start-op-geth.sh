#!/bin/sh
set -e

# Wait for the Bedrock flag for this network to be set.
echo "Waiting for Bedrock node to initialize..."
while [ ! -f /shared/initialized.txt ]; do
  sleep 1
done

# Override Holocene
if [ ! -z "$OVERRIDE_HOLOCENE" ]; then
  EXTENDED_ARG="$EXTENDED_ARG --override.holocene=$OVERRIDE_HOLOCENE"
fi

# Start op-geth.
exec geth \
  --op-network=$NETWORK_NAME \
  --datadir="$BEDROCK_DATADIR" \
  --http \
  --http.corsdomain="*" \
  --http.vhosts="*" \
  --http.addr=0.0.0.0 \
  --http.port=8545 \
  --http.api=eth,engine,web3,debug,net \
  --metrics \
  --metrics.influxdb \
  --metrics.influxdb.endpoint=http://influxdb:8086 \
  --metrics.influxdb.database=opgeth \
  --authrpc.vhosts="*" \
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
  $EXTENDED_ARG $@
