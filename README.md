# Ink Node

> Forked and customized from https://github.com/smartcontracts/simple-optimism-node

A Docker Compose setup for running an Ink node, plus the supporting
healthcheck and monitoring services.

## Versions

| Component | Version |
|---|---|
| Execution client | `op-reth` `v2.6.0` |
| `op-node` | `v1.19.8` |

`op-geth` reached end of support on **May 31, 2026**, and the **Karst**
hardfork activated on Ink Mainnet on **July 8, 2026** without `op-geth` support.
This stack runs `op-reth` as its execution client. Post-Karst `op-reth` needs
`op-node` `v1.19.1` or later because of the new `getPayloadV5` engine API
method, and `op-reth` `v2.3.3` or later (`v2.3.2` shipped a known
`eth_estimateGas` bug after Karst activation).

See the
[op-geth deprecation notice](https://docs.optimism.io/notices/op-geth-deprecation)
and the
[op-reth configuration guide](https://docs.optimism.io/node-operators/guides/configuration/execution-clients#op-reth-configuration).

### Migrating from the `op-geth` stack

- `op-geth` data cannot be reused. `op-reth` starts from an `op-reth` snapshot
  (see [Snapshot sources](#snapshot-sources)), so run `docker compose down -v`
  once, or remove the old `op_geth` volume, to reclaim the disk
- Port variables were renamed from `PORT__OP_GETH_*` to `PORT__OP_RETH_*`, and
  `envs/<network>/op-geth.env` is now `envs/<network>/op-reth.env`. Update any
  existing `.env`
- InfluxDB and its `opgeth` database are gone. The dashboard reads `op-reth`
  metrics from Prometheus instead
- `op-node` flags `--rollup.halt` and `--rollup.load-protocol-versions` were
  removed upstream and are no longer passed

## Recommended Hardware

### Mainnet

- 16GB+ RAM
- 2 TB SSD (NVME recommended)
- 100 Mbps+ download

### Testnet

- 16GB+ RAM
- 500 GB SSD (NVME recommended)
- 100 Mbps+ download

## Prerequisites

- Docker Engine and Docker Compose v2 on Linux, or Docker Desktop on macOS and
  Windows
- Working L1 execution RPC and L1 beacon API endpoints for the Ethereum network
  that matches your target Ink network. After the snapshot restore, `op-node`
  derives the chain from L1 starting at the snapshot date, so the L1 RPC must
  serve receipts for blocks up to about a week old and have high rate limits.
  Free public endpoints are not enough (see
  [`op-node` cannot connect to L1](#op-node-cannot-connect-to-l1))
- Enough free disk for your chosen node type

On Apple Silicon, the `healthcheck` sidecar runs as `linux/amd64`. Docker
Desktop handles this automatically, but the first startup can take longer.

### Ubuntu install

> If you are not logged in as root, log out and back in after adding yourself to
> the `docker` group.

```sh
sudo apt-get update
sudo apt-get upgrade -y

sudo apt-get install -y curl gnupg ca-certificates lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $(whoami)
```

Verify Docker after logging back in:

```sh
docker ps
```

## Quick Start

### 1. Clone the repo

```sh
git clone https://github.com/inkonchain/node
cd node
```

### 2. Copy the env template

```sh
cp .env.example .env
```

### 3. Edit `.env`

For the lowest-friction first run, start with `ink-sepolia` and a `full` node:

```sh
NETWORK_NAME=ink-sepolia
NODE_TYPE=full
OP_NODE__RPC_ENDPOINT=<your Sepolia execution RPC>
OP_NODE__L1_BEACON=<your Sepolia beacon API>
OP_NODE__RPC_TYPE=basic
HEALTHCHECK__REFERENCE_RPC_PROVIDER=https://rpc-gel-sepolia.inkonchain.com
```

Configuration notes:

- `NETWORK_NAME`: `ink-sepolia` or `ink-mainnet`
- `NODE_TYPE=full`: restores the latest `op-reth` full snapshot and runs
  `op-reth --full`, which prunes old state
- `NODE_TYPE=archive`: restores the latest `op-reth` archive snapshot and keeps
  all history. See [Snapshot sources](#snapshot-sources) for download sizes
- `OP_NODE__RPC_TYPE=basic`: the right default for generic providers; use
  `alchemy`, `quicknode`, or `erigon` only when your provider requires it
- `.env` overrides the same variable for services that load `.env` in
  `docker-compose.yml`, including `op-reth`, `op-node`, `healthcheck`, and
  `bedrock-init`
- `envs/<network>/op-node.env` already supplies the network P2P defaults, so
  most first-time setups only need the `.env` values above
- `PORT__OP_NODE_P2P` changes the published host port in `docker-compose.yml`.
  The in-container `op-node` listener still uses `9003`
- For `ink-mainnet`, switch the healthcheck reference RPC to
  `https://rpc-gel.inkonchain.com`
- Advanced wrapper inputs such as `OVERRIDE_HOLOCENE` and `EXTENDED_ARG` live
  in `.env.example`. `EXTENDED_ARG` is appended to both `op-reth` and `op-node`,
  and `OVERRIDE_HOLOCENE` to `op-node` only, so leave them empty unless you
  know the flag is compatible with the process you want to change

### 4. Start the stack

```sh
docker compose up -d --build
```

This pulls the service images, builds the local `bedrock-init` image, downloads
and extracts the latest `op-reth` snapshot, creates a JWT, and starts:

- `bedrock-init` (one-time init)
- `op-reth` (execution client)
- `op-node`
- `healthcheck`
- `prometheus`
- `grafana`

`op-reth` and `op-node` both wait for `bedrock-init` to create
`/shared/initialized.txt`. The snapshot is hundreds of GB, so the first start can
take a long time. If the stack looks stuck, check `bedrock-init` first.

## Validate Startup

### Check service status

```sh
docker compose ps
```

Expect the long-running services to be `Up`. `bedrock-init` is a one-time init
container, so it will usually disappear from default `docker compose ps` output
once it exits. If you want to confirm it finished successfully, run
`docker compose ps -a` and check that `bedrock-init` exited with code `0`.

### Check the key logs

```sh
docker compose logs --tail 50 bedrock-init op-reth op-node
```

Good startup signals:

- `bedrock-init` on first boot: `Creating JWT...` and `Creating Bedrock flag...`
- `bedrock-init` on restart with existing volumes: `Bedrock node already initialized`
- `op-reth`: `RPC HTTP server started`
- `op-node`: `Rollup node started`

### Smoke test the RPC endpoints

Execution RPC for the `op-reth` service:

```sh
curl -fsS -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://127.0.0.1:9993
```

Rollup node RPC:

```sh
curl -fsS -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"rpc_modules","params":[],"id":1}' http://127.0.0.1:9545
```

On `ink-sepolia`, a healthy reply includes the `optimism`, `opp2p`, and
`health` modules.

Sync status:

```sh
curl -fsS -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' http://127.0.0.1:9545
```

This is the best early signal that the rollup node is moving forward. Look for
`current_l1` to advance toward `head_l1`. Right after a snapshot restore,
`unsafe_l2` and `eth_blockNumber` stay at the snapshot height until derivation
produces new blocks.

Healthcheck metrics:

```sh
curl -fsS http://127.0.0.1:7300/metrics | grep -E 'healthcheck_(reference_height|target_height|height_difference)'
```

After restoring a snapshot, `eth_blockNumber` starts at the snapshot height and
catches up to the chain head. Use `optimism_syncStatus` and the healthcheck
metrics to confirm the node is moving forward during catch-up.

### Open Grafana

Grafana is available at [http://localhost:3000](http://localhost:3000).

- Username: `admin`
- Password: `ink`

The preloaded dashboard is `Simple Node Dashboard`.

## Operating The Node

### View logs

```sh
docker compose logs -f --tail 50
```

Or for a single service:

```sh
docker compose logs -f --tail 50 op-node
```

### Stop

```sh
docker compose down
```

This stops the stack without removing data volumes.

### Restart

```sh
docker compose restart
```

### Upgrade

```sh
git pull
docker compose pull
docker compose up -d --build
```

### Wipe All Data

```sh
docker compose down -v
```

This removes all local chain and monitoring data.

## Monitoring

### Estimate remaining sync time

`progress.sh` uses Foundry's `cast` on the host machine.

The `bedrock-init` container installs Foundry for its own image build, but that
does not make `cast` available on your host shell. Install Foundry locally if
you want to use `progress.sh`.

Install Foundry from [https://getfoundry.sh/](https://getfoundry.sh/) and then
run:

```sh
./progress.sh
```

Right after startup, `./progress.sh` can return `Error: Not syncing` until the
execution client starts importing blocks. In that phase, use
`optimism_syncStatus` and the healthcheck metrics from the validation section,
then retry the script.

If you do not want to install `cast`, use the RPC and metrics checks above
instead.

## P2P endpoints

The `op-node` bootstrap and static peers for each network are already set in
`envs/<network>/op-node.env`, so a clean checkout needs no manual peering setup.

The values below are execution-layer peers and are **not** used by the current
stack: `op-reth` runs with no peers and discovery disabled, because `op-node`
runs `--syncmode=consensus-layer` and payloads arrive over the Engine API. They
are recorded here as a reference if you want to enable `op-reth` P2P (remove
`--max-outbound-peers=0 --max-inbound-peers=0` and the `--disable-*-discovery`
flags in `scripts/start-op-reth.sh`).

`op-reth` `--bootnodes`, both networks:

```
enode://ca2774c3c401325850b2477fd7d0f27911efbf79b1e8b335066516e2bd8c4c9e0ba9696a94b1cb030a88eac582305ff55e905e64fb77fe0edcd70a4e5296d3ec@34.65.175.185:30305?discport=30305
enode://dd751a9ef8912be1bfa7a5e34e2c3785cc5253110bd929f385e07ba7ac19929fb0e0c5d93f77827291f4da02b2232240fbc47ea7ce04c46e333e452f8656b667@34.65.107.0:30305?discport=30305
enode://c5d289b56a77b6a2342ca29956dfd07aadf45364dde8ab20d1dc4efd4d1bc6b4655d902501daea308f4d8950737a4e93a4dfedd17b49cd5760ffd127837ca965@34.65.202.239:30305?discport=30305
```

`op-reth` `--trusted-peers`, mainnet:

```
enode://61164c944eba34a2d4f50682fd71fa966df42ffcf32bd962810c004acf47f574efd6d0d293bd7c6ffe964524468a98f1cd9427dca2bf54dcfa375d34e5a25fc7@34.178.90.179:30304?discport=30303
enode://3812d9e130a2f45761431935f0e2ad4a12e9389772a96e4e83e48a38722b44f02af7df32204a7a6f6fa91c38f7ba12a03178a7c6d5624dc45f87a79d076a95cb@34.6.15.128:30304?discport=30303
enode://b708474c6db25e99320daebd2d9a8b29139a676fad976e134eb6ca6271d7525510a361efe1b0828e9288b3d33cb8edcb602d8aea335fab086ad6e38251775f91@34.178.42.30:30304?discport=30303
```

`op-reth` `--trusted-peers`, sepolia:

```
enode://9978a50acf8f7c30c8cbd657a653c2faaf4033c62c9f288a2ae88b31ac121cf5c419788d4f0b45cc5fd75d05e29bd05f59c0c5339b6726c9ea41bca4108f4bcc@34.6.8.218:30304?discport=30303
enode://8e23c7c584b7b0808269dc74f825d68daa0df2a331c92b0c4c638b951607affa4ea614098f98791b68c73922ebbe146a5ae1e40a8d158babb372e11433091499@34.141.131.99:30304?discport=30303
enode://c2dd4ad2f3f5dd2e3d6c77acbb4f96a73d692f3172181caf457863bd9ac0645c4b709b98e8c2fa6e6d218135268635d85224b2623480290ac4dad22f0cb31b4b@35.204.224.2:30304?discport=30303
```

## Troubleshooting

### `bedrock-init` says `Bedrock node already initialized`

That means the stack is reusing existing Docker volumes. This is expected on
restarts. If you intentionally want a clean first-boot flow, wipe the volumes:

```sh
docker compose down -v
```

### `bedrock-init` takes a long time

That is expected while the snapshot is downloading and extracting. Snapshots are
roughly 250-400 GB. Check:

```sh
docker compose logs -f bedrock-init
```

If image pulls or snapshot downloads fail, make sure the host can reach:

- `docker.io`
- `us-docker.pkg.dev`
- `snapshots.optimism.io`
- `*.r2.cloudflarestorage.com` (snapshot downloads redirect here)

If `bedrock-init` exits with `Unexpected checksum file format`,
`Checksum file does not match downloaded archive`, or `SHA256 verification
failed`, do not reuse that download. Retry later or verify the checksum
yourself before attempting another restore.

### Snapshot sources

Ink snapshots are published by Optimism at
[https://snapshots.optimism.io/](https://snapshots.optimism.io/). The former
Gelato ChainSnap indexes (`ink.snapshots.gelato.cloud` and
`ink.t.snapshots.gelato.cloud`) are retired.

The service lists `op-reth` `full` and `archive` snapshots for both Ink
Mainnet (`ink-mainnet-0`) and Ink Sepolia (`ink-sepolia-0`). `bedrock-init`
downloads the latest snapshot matching `NODE_TYPE` from a stable "latest"
download pair:

```
https://snapshots.optimism.io/api/snapshots/<network>/latest/<full|archive>/archive
https://snapshots.optimism.io/api/snapshots/<network>/latest/<full|archive>/checksum
```

For example, the latest Ink Sepolia full snapshot:

```sh
curl -LOJ https://snapshots.optimism.io/api/snapshots/ink-sepolia-0/latest/full/checksum
curl -LOJ https://snapshots.optimism.io/api/snapshots/ink-sepolia-0/latest/full/archive
sha256sum -c ink-sepolia-0-op-reth-full-*.tar.zst.sha256sum
```

Both endpoints redirect to a presigned Cloudflare R2 URL, so follow redirects.
Archives are `.tar.zst`, and the checksum file names the dated archive it
covers, so `-OJ` keeps the two filenames in sync.

These are `op-reth` datadirs, so `bedrock-init` extracts them straight into
the `op_reth` volume. To be safe, do not mix `NODE_TYPE` values on one volume: wipe the
volumes before switching between `full` and `archive`.

### `eth_blockNumber` looks stuck right after startup

`op-reth` only advances once `op-node` is connected to L1 and sending payloads
over the Engine API. Check the rollup node:

```sh
curl -fsS -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' http://127.0.0.1:9545
```

### `./progress.sh` says `Error: Not syncing`

That is expected until the execution client starts importing blocks. The script
samples `eth_blockNumber` twice over 10 seconds, so it cannot estimate sync
speed before then. Use `optimism_syncStatus` and the healthcheck metrics first,
then retry later.

### `op-node` logs L1 receipt errors, or `current_l1` is stuck

After a snapshot restore, `op-node` fetches L1 receipts starting at the snapshot
date. Typical symptoms with an under-provisioned L1 RPC:

- `receipt 0 has unexpected nil block number`: the provider does not serve
  receipts for older blocks (seen with PublicNode on Ink Sepolia)
- `429 Too Many Requests`: the provider is rate limiting (seen with Tenderly's
  public gateway)
- `Batch of more than 3 requests are not allowed`: the provider limits batch
  size. Set `OP_NODE_L1_RPC_MAX_BATCH_SIZE=3` in `.env`. With dRPC's free plan
  this unblocked derivation, but it still advanced only about 0.13 L1 blocks per
  second against L1's 0.083 blocks per second of chain growth, so a multi-day
  gap takes days to close

Use a provider with receipt history and higher limits for the L1 execution RPC.
Progress is visible as `current_l1` rising in `optimism_syncStatus`.

### `op-node` cannot connect to L1

Double-check:

- `OP_NODE__RPC_ENDPOINT`
- `OP_NODE__L1_BEACON`
- `OP_NODE__RPC_TYPE`

Then restart the stack:

```sh
docker compose down
docker compose up -d --build
```

### `error dialing static peer` appears in `op-node` logs

That can happen during early bootstrap if a configured static peer is
temporarily unavailable. If those errors continue against every configured peer,
inspect `envs/<network>/op-node.env` and your outbound network access; stale peer
endpoints are the usual cause. Note that `current_l1` can keep advancing with
zero peers, since the node still derives the safe chain from L1 — check
`opp2p_peerStats.connected` to confirm P2P health.

### `Walking back L1Block` appears in the logs

A few reset lines during first startup are normal. If the node keeps printing
them without any L1 progress, verify the L1 endpoints above and restart the
stack.
