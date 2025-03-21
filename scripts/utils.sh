#!/bin/bash

# extract: Extracts an archive into an output location.
# Arguments:
#   arc: Archive to extract.
#   loc: Location to extract to.
function extract() {
  mkdir -p $2
  tar -xf $1 -C $2
}

# extractzst: Extracts a zst archive into an output location.
# Arguments:
#   arc: ZST archive to extract.
#   loc: Location to extract to.
function extractzst() {
  mkdir -p $2
  tar --use-compress-program=unzstd -xf $1 -C $2
}

# extractlz4: Extracts a lz4 archive into an output location.
# Arguments:
#   arc: lz4 archive to extract.
#   loc: Location to extract to.
function extractlz4() {
  mkdir -p $2
  tar --use-compress-program="lz4 --no-crc" -xf $1 -C $2
}

# download: Downloads a file and provides basic progress percentages.
# Arguments:
#   url: URL of the file to download.
#   out: Location to download the file to.
function download() {
  aria2c --max-tries=0 -x 16 -s 16 -k100M -o $2 $1
}
