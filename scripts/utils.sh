#!/bin/bash

# extract: Extracts an archive into an output location.
# Arguments:
#   arc: Archive to extract.
#   loc: Location to extract to.
function extract() {
  mkdir -p "$2"
  tar -xf "$1" -C "$2"
}

# extractzst: Extracts a zst archive into an output location.
# Arguments:
#   arc: ZST archive to extract.
#   loc: Location to extract to.
function extractzst() {
  mkdir -p "$2"
  tar --use-compress-program=unzstd -xf "$1" -C "$2"
}

# extractlz4: Extracts a lz4 archive into an output location.
# Arguments:
#   arc: lz4 archive to extract.
#   loc: Location to extract to.
function extractlz4() {
  mkdir -p "$2"
  tar --use-compress-program="lz4 --no-crc" -xf "$1" -C "$2"
}

# download: Downloads a file and provides basic progress percentages.
# Arguments:
#   url: URL of the file to download.
#   out: Location to download the file to.
function download() {
  local out_dir out_name
  out_dir="$(dirname "$2")"
  out_name="$(basename "$2")"

  mkdir -p "$out_dir"
  aria2c --max-tries=0 -x 16 -s 16 -k100M --dir="$out_dir" --out="$out_name" "$1"
}

# verify_sha256_checksum: Verifies a downloaded file against a checksum file.
# Arguments:
#   file_path: Path to the downloaded file.
#   checksum_path: Path to the checksum file.
#   expected_name: Expected archive filename from the checksum file.
function verify_sha256_checksum() {
  local file_path="$1"
  local checksum_path="$2"
  local expected_name="$3"
  local expected_hash checksum_name extra actual_hash

  read -r expected_hash checksum_name extra < "$checksum_path"
  checksum_name="${checksum_name#\*}"

  if [[ -z "$expected_hash" || -z "$checksum_name" || -n "$extra" ]]; then
    echo "Unexpected checksum file format: $checksum_path" >&2
    exit 1
  fi

  if [[ ! "$expected_hash" =~ ^[A-Fa-f0-9]{64}$ ]]; then
    echo "Unexpected checksum value in: $checksum_path" >&2
    exit 1
  fi

  if [[ "$checksum_name" != "$expected_name" ]]; then
    echo "Checksum file does not match downloaded archive: $checksum_path" >&2
    exit 1
  fi

  actual_hash="$(sha256sum "$file_path" | awk '{print $1}')"
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    echo "SHA256 verification failed for: $file_path" >&2
    exit 1
  fi
}
