#!/bin/bash

# Make script exit on error and undefined variables
set -eu

# Function to handle errors
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Load Environment Variables
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' ) || error_exit "Failed to load .env file"
fi

# Set default RPC URL with error checking
export ETH_RPC_URL=${ETH_RPC_URL:-http://localhost:${PORT__OP_GETH_HTTP:-9993}}
[ -z "$ETH_RPC_URL" ] && error_exit "ETH_RPC_URL is not set"

# Get chain ID with error handling
CHAIN_ID=$(cast chain-id 2>/dev/null) || error_exit "Failed to get chain ID"
echo "Chain ID: $CHAIN_ID"
echo "Sampling, please wait"

# Set L2_URL based on chain ID
echo "Determining L2_URL for chain ID: $CHAIN_ID"
case $CHAIN_ID in
    763373)
        echo "Using Sepolia testnet RPC endpoint"
        L2_URL="https://rpc-gel-sepolia.inkonchain.com"
        ;;
    57073)
        echo "Using mainnet RPC endpoint"
        L2_URL="https://rpc-gel.inkonchain.com/"
        ;;
    *)
        error_exit "Unsupported chain ID: $CHAIN_ID"
        ;;
esac
echo "L2_URL set to: $L2_URL"

echo "Getting initial block number..."
T0=$(cast block-number --rpc-url "$ETH_RPC_URL" 2>/dev/null) || error_exit "Failed to get initial block number"
echo "Initial block: $T0"
echo "Waiting 10 seconds..."
sleep 10
echo "Getting final block number..."
T1=$(cast block-number --rpc-url "$ETH_RPC_URL" 2>/dev/null) || error_exit "Failed to get final block number"
echo "Final block: $T1"

# Calculate blocks per minute
PER_MIN=$(($T1 - $T0))
PER_MIN=$(($PER_MIN * 6))
echo "Blocks per minute: $PER_MIN"

[ $PER_MIN -eq 0 ] && error_exit "Not syncing"

# Get L2 head block with error handling
HEAD=$(cast block-number --rpc-url "$L2_URL" 2>/dev/null) || error_exit "Failed to get L2 block number"
BEHIND=$((HEAD - T1))
if [ $BEHIND -lt 0 ]; then
    error_exit "Local node is ahead of remote L2 RPC endpoint (local: $T1, remote: $HEAD)"
fi

if [ $BEHIND -eq 0 ]; then
    echo "Local node is fully synced with L2 head (block $HEAD)."
    exit 0
fi

# Calculate time estimates
echo "Calculating time estimates..."
MINUTES=$((BEHIND / PER_MIN))
HOURS=$((MINUTES / 60))

if [ $HOURS -ge 24 ]; then
    DAYS=$((HOURS / 24))
    echo "Sync will take days"
    echo "Days until sync complete: $DAYS (approx $HOURS hours)"
elif [ $MINUTES -ge 60 ]; then
    echo "Sync will take hours"
    echo "Hours until sync completed: $HOURS (approx $MINUTES minutes)"
else
    echo "Sync will complete in minutes"
    echo "Minutes until sync completed: $MINUTES"
fi
