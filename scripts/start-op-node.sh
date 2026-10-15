#!/bin/sh
set -e

# Wait for the Bedrock flag for this network to be set.
echo "Waiting for Bedrock node to initialize..."
while [ ! -f /shared/initialized.txt ]; do
  sleep 1
done

# PORT__OP_NODE_P2P changes the published host port in docker-compose.
# Keep the in-container listener fixed to match the container-side mapping.
P2P_PORT="9003"
L1_RPC_ENDPOINT="$OP_NODE__RPC_ENDPOINT"
L1_BEACON_ENDPOINT="$OP_NODE__L1_BEACON"
L1_RPC_TYPE="$OP_NODE__RPC_TYPE"
export EXTENDED_ARG="${EXTENDED_ARG:-} --network=$NETWORK_NAME"

# Override Holocene
if [ ! -z "$OVERRIDE_HOLOCENE" ]; then
  EXTENDED_ARG="$EXTENDED_ARG --override.holocene=$OVERRIDE_HOLOCENE"
fi

# These vars are wrapper inputs, not native op-node env flags.
unset OP_NODE__RPC_ENDPOINT OP_NODE__L1_BEACON OP_NODE__RPC_TYPE

# Start op-node.
exec op-node \
  --l1="$L1_RPC_ENDPOINT" \
  --l2=http://op-reth:8551 \
  --rpc.addr=0.0.0.0 \
  --rpc.port=9545 \
  --l2.jwt-secret=/shared/jwt.txt \
  --l1.trustrpc \
  --l1.rpckind="$L1_RPC_TYPE" \
  --l1.beacon="$L1_BEACON_ENDPOINT" \
  --metrics.enabled \
  --metrics.addr=0.0.0.0 \
  --metrics.port=7300 \
  --syncmode=consensus-layer \
  --p2p.scoring=none \
  --p2p.listen.ip=0.0.0.0 \
  --p2p.listen.tcp="$P2P_PORT" \
  --p2p.listen.udp="$P2P_PORT" \
  $EXTENDED_ARG $@
