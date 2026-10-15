#!/bin/bash
set -e

# Import utilities.
source ./scripts/utils.sh

# Common variables.
INITIALIZED_FLAG=/shared/initialized.txt
BEDROCK_JWT_PATH=/shared/jwt.txt
RETH_DATA_DIR=$BEDROCK_DATADIR
SNAPSHOT_PATH=/downloads/snapshot.tar.zst
SNAPSHOT_CHECKSUM_PATH=/downloads/snapshot.tar.zst.sha256
SNAPSHOTS_BASE_URL="https://snapshots.optimism.io/api/snapshots"

function validate_snapshot_filename() {
  local snapshot_filename="$1"

  if [[ ! "$snapshot_filename" =~ ^[A-Za-z0-9._-]+\.tar\.zst$ ]]; then
    echo "Unexpected snapshot filename format: $snapshot_filename" >&2
    exit 1
  fi
}

# Exit early if we've already initialized.
if [ -e "$INITIALIZED_FLAG" ]; then
  echo "Bedrock node already initialized"
  exit 0
fi

echo "Bedrock node needs to be initialized..."
echo "Initializing via download..."

# Resolve the latest op-reth snapshot published at https://snapshots.optimism.io/
# for this network. Snapshot networks are named <network>-0.
case "$NODE_TYPE" in
  full | archive) ;;
  *)
    echo "Unsupported NODE_TYPE: $NODE_TYPE (expected full or archive)" >&2
    exit 1
    ;;
esac

case "$NETWORK_NAME" in
  ink-mainnet | ink-sepolia) ;;
  *)
    echo "Unsupported network: $NETWORK_NAME" >&2
    exit 1
    ;;
esac

SNAPSHOT_URL="$SNAPSHOTS_BASE_URL/$NETWORK_NAME-0/latest/$NODE_TYPE"

echo "Downloading snapshot checksum..."
curl -fsSL "$SNAPSHOT_URL/checksum" -o "$SNAPSHOT_CHECKSUM_PATH"

# The checksum file is "<sha256>  <snapshot filename>".
read -r _ SNAPSHOT_FILENAME _ < "$SNAPSHOT_CHECKSUM_PATH"
validate_snapshot_filename "$SNAPSHOT_FILENAME"
echo "Using snapshot file: $SNAPSHOT_FILENAME"

echo "Downloading snapshot..."
download "$SNAPSHOT_URL/archive" "$SNAPSHOT_PATH"

echo "Verifying snapshot checksum..."
verify_sha256_checksum "$SNAPSHOT_PATH" "$SNAPSHOT_CHECKSUM_PATH" "$SNAPSHOT_FILENAME"

echo "Extracting snapshot..."
extractzst "$SNAPSHOT_PATH" "$RETH_DATA_DIR"

# Remove downloaded files to save disk space
rm "$SNAPSHOT_PATH"
rm "$SNAPSHOT_CHECKSUM_PATH"

echo "Creating JWT..."
mkdir -p "$(dirname "$BEDROCK_JWT_PATH")"
openssl rand -hex 32 > "$BEDROCK_JWT_PATH"

echo "Creating Bedrock flag..."
touch "$INITIALIZED_FLAG"
