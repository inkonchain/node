#!/bin/sh
set -eu

# Wait for the Bedrock flag for this network to be set.
echo "Waiting for Bedrock node to initialize..."
while [ ! -f /shared/initialized.txt ]; do
  sleep 1
done

# SECURITY FIX: Require the L1 endpoints that are necessary for a usable rollup node.
# The launcher now fails closed with actionable errors if these are absent.
L1_RPC_ENDPOINT="${OP_NODE__RPC_ENDPOINT:?Set OP_NODE__RPC_ENDPOINT in .env}"
L1_BEACON_ENDPOINT="${OP_NODE__L1_BEACON:?Set OP_NODE__L1_BEACON in .env}"
L1_RPC_TYPE="${OP_NODE__RPC_TYPE:-basic}"
P2P_PORT="9003"

# Pass the network and protocol settings as fixed arguments.
set -- \
  "--network=$NETWORK_NAME" \
  --rollup.load-protocol-versions=true \
  --rollup.halt=major \
  "$@"

# SECURITY FIX: Wire the documented per-network P2P defaults from envs/<network>/op-node.env
# directly into the op-node CLI flags.
if [ -n "${OP_NODE_P2P_BOOTNODES:-}" ]; then
  set -- "--p2p.bootnodes=$OP_NODE_P2P_BOOTNODES" "$@"
fi
if [ -n "${OP_NODE_P2P_STATIC:-}" ]; then
  set -- "--p2p.static=$OP_NODE_P2P_STATIC" "$@"
fi

# SECURITY FIX: Accept one explicit flag only to prevent shell argument injection.
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

# Start op-node with RPC and metrics bound inside the container network.
exec op-node \
  --l1="$L1_RPC_ENDPOINT" \
  --l2=http://op-geth:8551 \
  --rpc.addr=0.0.0.0 \
  --rpc.port=9545 \
  --l2.jwt-secret=/shared/jwt.txt \
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
  "$@"