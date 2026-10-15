#!/bin/sh
set -e

# Wait for the Bedrock flag for this network to be set.
echo "Waiting for Bedrock node to initialize..."
while [ ! -f /shared/initialized.txt ]; do
  sleep 1
done

# op-reth selects the network by chain name rather than the op-node/op-geth
# network name.
case "$NETWORK_NAME" in
  ink-mainnet) RETH_CHAIN="ink" ;;
  ink-sepolia) RETH_CHAIN="ink-sepolia" ;;
  *)
    echo "Unsupported network: $NETWORK_NAME" >&2
    exit 1
    ;;
esac

# op-reth keeps full history by default. "full" prunes old state.
if [ "$NODE_TYPE" = "full" ]; then
  EXTENDED_ARG="$EXTENDED_ARG --full"
fi

# Start op-reth.
exec op-reth node \
  --chain="$RETH_CHAIN" \
  --datadir="$BEDROCK_DATADIR" \
  --http \
  --http.corsdomain="*" \
  --http.addr=0.0.0.0 \
  --http.port=8545 \
  --http.api=eth,web3,debug,net \
  --ws \
  --ws.addr=0.0.0.0 \
  --ws.port=8546 \
  --ws.api=eth,web3,net \
  --metrics=0.0.0.0:9001 \
  --authrpc.addr=0.0.0.0 \
  --authrpc.port=8551 \
  --authrpc.jwtsecret=/shared/jwt.txt \
  --rollup.sequencer="$BEDROCK_SEQUENCER_HTTP" \
  --rollup.disable-tx-pool-gossip \
  --port="${PORT__OP_RETH_P2P:-39393}" \
  --discovery.port="${PORT__OP_RETH_P2P:-39393}" \
  --max-outbound-peers=0 \
  --max-inbound-peers=0 \
  --disable-discv4-discovery \
  --disable-discv5-discovery \
  --disable-dns-discovery \
  --txpool.pricebump=10 \
  --rpc.txfeecap=4 \
  $EXTENDED_ARG $@
