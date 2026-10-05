#!/bin/bash
set -e

# Import utilities.
source ./scripts/utils.sh

# Common variables.
INITIALIZED_FLAG=/shared/initialized.txt
BEDROCK_JWT_PATH=/shared/jwt.txt
: "${BEDROCK_DATADIR:?BEDROCK_DATADIR is not set (expected from envs/<network>/op-geth.env)}"
GETH_DATA_DIR="$BEDROCK_DATADIR"
BEDROCK_TAR_PATH=/downloads/bedrock.tar
BEDROCK_TAR_CHECKSUM_PATH=
# Optional operator override: a geth datadir tarball URL (with a matching
# <url>.sha256). Honoured in archive mode, so a node can bootstrap from a
# snapshot mirror even when the hosted index below is unreachable.
BEDROCK_TAR_DOWNLOAD="${BEDROCK_TAR_DOWNLOAD:-}"

function validate_snapshot_filename() {
  local snapshot_filename="$1"

  if [[ -z "$snapshot_filename" ]]; then
    echo "Snapshot filename lookup returned an empty response" >&2
    exit 1
  fi

  if [[ ! "$snapshot_filename" =~ ^[A-Za-z0-9._-]+\.tar(\.zst|\.lz4)?$ ]]; then
    echo "Unexpected snapshot filename format: $snapshot_filename" >&2
    exit 1
  fi
}

function snapshot_bootstrap_hint() {
  cat >&2 <<'EOF'
Either set NODE_TYPE=full in .env to sync from genesis, or set
BEDROCK_TAR_DOWNLOAD in .env to a geth datadir tarball that has a
matching <url>.sha256 checksum file.
EOF
}

function resolve_latest_snapshot_filename() {
  local index_url="$1"
  local filename_regex="$2"
  local index_content snapshot_filename

  if ! index_content="$(curl -fsS "$index_url")"; then
    echo "Could not fetch the snapshot index: $index_url" >&2
    echo "The hosted snapshot index is unreachable or no longer published." >&2
    snapshot_bootstrap_hint
    exit 1
  fi

  snapshot_filename="$(
    printf '%s' "$index_content" | python3 -c '
import re
import sys

filename_pattern = re.compile(sys.argv[1])
timestamp_pattern = re.compile(r"-(\d+)\.tar(?:\.(?:zst|lz4))?$")
content = sys.stdin.read()

matches = sorted(
    {match.group(0) for match in filename_pattern.finditer(content)},
    key=lambda name: int(timestamp_pattern.search(name).group(1)),
    reverse=True,
)

if not matches:
    sys.exit(1)

print(matches[0])
' "$filename_regex"
  )" || {
    echo "No snapshot file matching $filename_regex was listed at $index_url" >&2
    snapshot_bootstrap_hint
    exit 1
  }

  validate_snapshot_filename "$snapshot_filename"
  echo "$snapshot_filename"
}

# Exit early if we've already initialized.
if [ -e "$INITIALIZED_FLAG" ]; then
  echo "Bedrock node already initialized"
  exit 0
fi

echo "Bedrock node needs to be initialized..."
echo "Initializing via download..."

# Fail fast on an unknown node type: without this, a typo such as
# NODE_TYPE=ful would silently fall through and sync from genesis as a
# full node.
if [ "$NODE_TYPE" != "archive" ] && [ "$NODE_TYPE" != "full" ]; then
  echo "Unsupported node type: $NODE_TYPE (expected 'full' or 'archive')" >&2
  exit 1
fi

# Resolve the latest archival geth datadir snapshot from the ChainSnap indexes.
echo "Fetching download link..."

if [ "$NODE_TYPE" = "archive" ]; then
  if [ -n "$BEDROCK_TAR_DOWNLOAD" ]; then
    echo "Using snapshot from BEDROCK_TAR_DOWNLOAD: $BEDROCK_TAR_DOWNLOAD"
  elif [ "$NETWORK_NAME" = "ink-sepolia" ]; then
    SNAPSHOT_FILENAME="$(resolve_latest_snapshot_filename \
      "https://ink.t.snapshots.gelato.cloud/index.html" \
      'ink-sepolia-geth-archival-datadir-[0-9]+-[0-9]+\.tar(?:\.(?:zst|lz4))?')"
    BEDROCK_TAR_DOWNLOAD="https://ink.t.snapshots.gelato.cloud/geth/archival/datadir/$SNAPSHOT_FILENAME"
    echo "Using snapshot file: $SNAPSHOT_FILENAME"
  elif [ "$NETWORK_NAME" = "ink-mainnet" ]; then
    SNAPSHOT_FILENAME="$(resolve_latest_snapshot_filename \
      "https://ink.snapshots.gelato.cloud/index.html" \
      'ink-geth-archival-datadir-[0-9]+-[0-9]+\.tar(?:\.(?:zst|lz4))?')"
    BEDROCK_TAR_DOWNLOAD="https://ink.snapshots.gelato.cloud/geth/archival/datadir/$SNAPSHOT_FILENAME"
    echo "Using snapshot file: $SNAPSHOT_FILENAME"
  else
    echo "Unsupported archive network: $NETWORK_NAME" >&2
    exit 1
  fi
fi

if [ -n "$BEDROCK_TAR_DOWNLOAD" ]; then
  if [[ "$BEDROCK_TAR_DOWNLOAD" == *.zst ]]; then
    BEDROCK_TAR_PATH+=".zst"
  elif [[ "$BEDROCK_TAR_DOWNLOAD" == *.lz4 ]]; then
    BEDROCK_TAR_PATH+=".lz4"
  fi
  BEDROCK_TAR_CHECKSUM_PATH="${BEDROCK_TAR_PATH}.sha256"

  echo "Downloading bedrock.tar checksum..."
  if ! curl -fsS "$BEDROCK_TAR_DOWNLOAD.sha256" -o "$BEDROCK_TAR_CHECKSUM_PATH"; then
    echo "Could not fetch the checksum file: $BEDROCK_TAR_DOWNLOAD.sha256" >&2
    echo "Every snapshot URL must be accompanied by a <url>.sha256 file." >&2
    exit 1
  fi

  echo "Downloading bedrock.tar..."
  download "$BEDROCK_TAR_DOWNLOAD" "$BEDROCK_TAR_PATH"

  echo "Verifying bedrock.tar checksum..."
  verify_sha256_checksum "$BEDROCK_TAR_PATH" "$BEDROCK_TAR_CHECKSUM_PATH" "$(basename "$BEDROCK_TAR_DOWNLOAD")"

  echo "Extracting bedrock.tar..."
  if [[ "$BEDROCK_TAR_DOWNLOAD" == *.zst ]]; then
    extractzst "$BEDROCK_TAR_PATH" "$GETH_DATA_DIR"
  elif [[ "$BEDROCK_TAR_DOWNLOAD" == *.lz4 ]]; then
    extractlz4 "$BEDROCK_TAR_PATH" "$GETH_DATA_DIR"
  else
    extract "$BEDROCK_TAR_PATH" "$GETH_DATA_DIR"
  fi

  # Remove tar file to save disk space
  rm "$BEDROCK_TAR_PATH"
  rm "$BEDROCK_TAR_CHECKSUM_PATH"
fi

echo "Creating JWT..."
mkdir -p "$(dirname "$BEDROCK_JWT_PATH")"
openssl rand -hex 32 > "$BEDROCK_JWT_PATH"

echo "Creating Bedrock flag..."
touch "$INITIALIZED_FLAG"
