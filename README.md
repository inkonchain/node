# Running an Ink Node 🐙

## Setup Instructions 🛠️

### Installation 📥

1. Download the latest snapshot from this Google Drive directory: [ink-geth-snapshots](https://drive.google.com/drive/folders/1uDm7C67Q98kRJQ6mRmeSElgdHUA6gylb?usp=sharing).
2. Move the downloaded `geth.tar.lz4` to root of the repository.
3. Run the setup script.
   ```
   ./setup.sh
   ```

### Configuration ⚙️

By default, the local Ink node leverages public RPC & Beacon APIs from publicnode.com.

If you prefer, you can use your own RPC & Beacon APIs by creating a `.env` file in the root of the repository with the following environment variables:

```sh
L1_RPC_URL=...
L1_BEACON_URL=...
```

### Execution 🚀

Start the Ink node using Docker Compose:

```sh
docker compose up # --build to force rebuild the images
```

## Verifying Sync Status 🔎

### op-node API 🌐

You can use the optimism_syncStatus method on the op-node API to know what’s the current status:

```sh
curl -X POST -H "Content-Type: application/json" --data \
    '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' \
    http://localhost:9545 | jq
```

### op-geth API 🌐

When your local node is fully synced, calling the eth_blockNumber method on the op-geth API should return the latest block number as seen on the [block explorer](https://sepolia-explorer.inkchain.xyz/).

```sh
curl http://localhost:8545 -X POST \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params": [],"id":1}' | jq -r .result | sed 's/^0x//' | awk '{printf "%d\n", "0x" $0}';
```

### Comparing w/ Remote RPC 👀

Use this script to compare your local finalized block with the one retrieved from the Remote RPC:

```sh
local_block=$(curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized", false],"id":1}' \
  | jq -r .result.number | sed 's/^0x//' | awk '{printf "%d\n", "0x" $0}'); \
remote_block=$(curl -s -X POST https://sepolia-rpc.inkchain.xyz/ -H "Content-Type: application/json" \
 --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized", false],"id":1}' \
 | jq -r .result.number | sed 's/^0x//' | awk '{printf "%d\n", "0x" $0}'); \
echo -e "Local finalized block: $local_block\nRemote finalized block: $remote_block"
```

The node is in sync when both the Local finalized block and Remote finalized block are equal. E.g.:

```
Local finalized block: 4449608
Remote finalized block: 4449608
```
