# Ink Node

> Forked and customized from https://github.com/smartcontracts/simple-optimism-node

A Docker Compose setup for running an Ink node on the repository's current
`op-geth`-based stack, plus the supporting healthcheck and monitoring services.

## Current Status

This repository currently ships an `op-geth` execution client. The instructions
below are the current `op-geth` runbook for this Compose stack, not the
long-term recommendation.

Per Optimism, `op-geth` support ends on May 31, 2026, and nodes still running
it at the L1 Glamsterdam hardfork will not be able to follow the canonical
chain. `op-node` is not being deprecated. See the
[op-geth deprecation notice](https://docs.optimism.io/notices/op-geth-deprecation)
and the
[op-reth configuration guide](https://docs.optimism.io/node-operators/guides/configuration/execution-clients#op-reth-configuration).

If you operate a production or long-lived node, start planning an `op-reth`
migration now. Run it in parallel, validate it over a meaningful window, and
prepare a fresh snapshot before the hardfork window. Treat this as an
operator-owned migration rather than something to delay until a later
sequencer-side client switch.

This repository does not yet ship an `op-reth` Compose path. Before it can, the
repo still needs:

- a validated `op-reth` service, image, and entrypoint in `docker-compose.yml`
- an `op-node` engine endpoint that no longer points at `http://op-geth:8551`
- archive init and snapshot handling that can consume `op-reth` snapshots where
  available. The checked Sepolia Ink Gelato index already exposes
  `reth/full/datadir` artifacts, but this repo does not use them yet and the
  checked mainnet Ink index still only exposes geth archives
- healthcheck and monitoring updates, which still target `op-geth` and the
  `opgeth` InfluxDB database
- env and port naming that no longer assumes `op-geth`, such as
  `PORT__OP_GETH_*` and `envs/*/op-geth.env`

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
  that matches your target Ink network
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

For the lowest-friction first run on the current `op-geth` stack, start with
`ink-sepolia` and a `full` node:

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
- `NODE_TYPE=full`: starts from an empty local datadir. This is the validated
  first-run path in this repo
- `NODE_TYPE=archive`: resolves the newest archival geth datadir for the
  current `op-geth` stack from the Gelato ChainSnap index for your network,
  downloads the matching `.sha256`, verifies the archive, and extracts it
  during `bedrock-init`
- `OP_NODE__RPC_TYPE=basic`: the right default for generic providers; use
  `alchemy`, `quicknode`, or `erigon` only when your provider requires it
- `.env` overrides the same variable for services that load `.env` in
  `docker-compose.yml`, including `op-geth`, `op-node`, `healthcheck`, and
  `bedrock-init`
- `HOST_BIND_ADDRESS` defaults to `127.0.0.1`, so host-published HTTP and
  monitoring services are local-only unless you explicitly choose another
  interface and provide the required network controls.
- Set unique, non-empty values for `GRAFANA_ADMIN_PASSWORD`,
  `INFLUXDB_ADMIN_PASSWORD`, `INFLUXDB_WRITE_USER_PASSWORD`, and
  `INFLUXDB_READ_USER_PASSWORD` in `.env` before starting the stack. These
  values are required and are not stored in the repository.
- Set explicit, reviewed values for `IMAGE_TAG__HEALTHCHECK`,
  `IMAGE_TAG__PROMETHEUS`, `IMAGE_TAG__GRAFANA`, and `IMAGE_TAG__INFLUXDB`.
  The Compose file has no mutable `latest` or floating-version fallback.
- The InfluxDB initialization variables apply only when the data volume is
  initialized for the first time. For an existing volume, create or rotate the
  users through an authenticated administrative procedure before restarting
  the stack; do not delete production data just to re-run initialization.
- `envs/<network>/op-node.env` already supplies the network P2P defaults, so

  most first-time setups only need the `.env` values above
- `PORT__OP_NODE_P2P` changes the published host port in `docker-compose.yml`.
  The in-container `op-node` listener still uses `9003`
- For `ink-mainnet`, switch the healthcheck reference RPC to
  `https://rpc-gel.inkonchain.com`
- Advanced wrapper inputs such as `OVERRIDE_HOLOCENE` and `EXTENDED_ARG` live
  in `.env.example`. The shell entrypoints append them to both `op-geth` and
  `op-node`, so leave them empty unless you know the flag is compatible with
  the process you want to change

### 4. Start the stack

```sh
docker compose up -d --build
```

This pulls the service images, builds the local `bedrock-init` image, creates a
JWT, and starts:

- `bedrock-init` (one-time init)
- `op-geth` (current execution client in this repo)
- `op-node`
- `healthcheck`
- `prometheus`
- `grafana`
- `influxdb`

`op-geth` and `op-node` both wait for `bedrock-init` to create
`/shared/initialized.txt`. If the stack looks stuck, check `bedrock-init`
first.

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
docker compose logs --tail 50 bedrock-init op-geth op-node
```

Good startup signals:

- `bedrock-init` on first boot: `Creating JWT...` and `Creating Bedrock flag...`
- `bedrock-init` on restart with existing volumes: `Bedrock node already initialized`
- `op-geth`: `HTTP server started`
- `op-node`: `Rollup node started`

### Smoke test the RPC endpoints

Execution RPC for the current `op-geth` service:

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

On a brand-new `full` node, this is the best early signal that the rollup node
is moving forward. Look for `current_l1` and `head_l1` values to advance even
while local L2 block height is still `0x0`.

Healthcheck metrics:

```sh
curl -fsS http://127.0.0.1:7300/metrics | grep -E 'healthcheck_(reference_height|target_height|height_difference)'
```

On a brand-new `full` node, `eth_blockNumber` can stay at `0x0` for a while.
That is expected. During that window it is also normal for
`healthcheck_target_height` to stay at `0`. Use `optimism_syncStatus` and the
healthcheck metrics to confirm the node is moving forward during early sync.

### Open Grafana

Grafana is available at [http://localhost:3000](http://localhost:3000) by
default because the Compose stack binds monitoring services to loopback.

Use the `GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD` values configured in
`.env`. There is no repository-provided default password. The preloaded
dashboard is `Simple Node Dashboard`.

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

On a brand-new `full` node, `./progress.sh` can return `Error: Not syncing`
while `eth_blockNumber` is still `0x0`. In that phase, use
`optimism_syncStatus` and the healthcheck metrics from the validation section,
then retry the script after the local block height starts moving.

If you do not want to install `cast`, use the RPC and metrics checks above
instead.

## P2P endpoints

The `op-node` bootstrap and static peers for each network are already set in
`envs/<network>/op-node.env`, so a clean checkout needs no manual peering setup.

The values below are execution-layer peers and are **not** used by the current
stack: `op-geth` runs with `--maxpeers=0 --nodiscover`, because `op-node` runs
`--syncmode=consensus-layer` and payloads arrive over the Engine API. They are
recorded here as the reference for the `op-reth` migration described in
[Current Status](#current-status).

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

### `bedrock-init` exits quickly on a full node

That is expected. `full` nodes do not download a snapshot. If you want a
snapshot restore path, switch to `NODE_TYPE=archive`.

### `bedrock-init` says `Bedrock node already initialized`

That means the stack is reusing existing Docker volumes. This is expected on
restarts. If you intentionally want a clean first-boot flow, wipe the volumes:

```sh
docker compose down -v
```

### `bedrock-init` takes a long time on an archive node

That is expected while the snapshot is downloading and extracting. Check:

```sh
docker compose logs -f bedrock-init
```

If image pulls or snapshot downloads fail, make sure the host can reach:

- `docker.io`
- `us-docker.pkg.dev`
- `ink.t.snapshots.gelato.cloud`
- `ink.snapshots.gelato.cloud`

Archive geth snapshots for the current stack are resolved from these indexes:

- Sepolia: [https://ink.t.snapshots.gelato.cloud/index.html](https://ink.t.snapshots.gelato.cloud/index.html)
- Mainnet: [https://ink.snapshots.gelato.cloud/index.html](https://ink.snapshots.gelato.cloud/index.html)

`bedrock-init` downloads the matching `.sha256` file and verifies the archive
before extraction. This is still a geth datadir path, not an `op-reth`
bootstrap flow.

At the time of this docs refresh, the Sepolia Ink Gelato index also exposes
`reth/full/datadir` artifacts, but the checked mainnet Ink index does not yet
show `reth` artifacts. This repository does not consume those `reth` snapshots
yet.

If `bedrock-init` exits with `Failed to resolve latest snapshot` or
`Unexpected snapshot filename format`, the index is unreachable or its format
changed. Switch back to `NODE_TYPE=full` and retry, or pick a direct archive
from the index page and update the script before retrying.

If `bedrock-init` exits with `Unexpected checksum file format`,
`Checksum file does not match downloaded archive`, or `SHA256 verification
failed`, do not reuse that download. Retry later or verify the checksum file
from the index page before attempting another restore.

### `eth_blockNumber` stays at `0x0` right after startup

That is normal for a fresh `full` node. Check the rollup node instead:

```sh
curl -fsS -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' http://127.0.0.1:9545
```

### `./progress.sh` says `Error: Not syncing`

That is expected during the earliest part of a fresh `full` node bootstrap. The
script samples `eth_blockNumber` twice over 10 seconds, so it cannot estimate
sync speed until the local execution client starts importing blocks. Use
`optimism_syncStatus` and the healthcheck metrics first, then retry later.

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
