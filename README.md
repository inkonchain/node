# Running an Ink Node 🐙

## Setup Instructions 🛠️

### Configuration ⚙️

To run the Ink node, it's required to bring your own L1 Sepolia Node. We suggest using [QuickNode](https://www.quicknode.com/) for this purpose.

Create a `.env` file in the root of the repository with the following environment variables, replacing `...` with your node's details:

```sh
L1_RPC_URL=...
L1_BEACON_URL=...
```

### Installation 📥

Run the setup script:

```
./setup.sh
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

When your local node is fully synced, calling the eth_blockNumber method on the op-geth API should return the latest block number as seen on the [block explorer](https://explorer-sepolia.inkonchain.com/).

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
remote_block=$(curl -s -X POST https://rpc-gel-sepolia.inkonchain.com/ -H "Content-Type: application/json" \
 --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized", false],"id":1}' \
 | jq -r .result.number | sed 's/^0x//' | awk '{printf "%d\n", "0x" $0}'); \
echo -e "Local finalized block: $local_block\nRemote finalized block: $remote_block"
```

The node is in sync when both the Local finalized block and Remote finalized block are equal. E.g.:

```
Local finalized block: 4449608
Remote finalized block: 4449608
```
