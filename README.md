# Ink Node

> Forked and customized from https://github.com/smartcontracts/simple-optimism-node

A simple docker compose script for launching full / archive node for the Ink chain.

## Recommended Hardware

### Mainnet

- 16GB+ RAM
- 2 TB SSD (NVME Recommended)
- 100mb/s+ Download

### Testnet

- 16GB+ RAM
- 500 GB SSD (NVME Recommended)
- 100mb/s+ Download

## Installation and Configuration

### Install docker and docker compose

> Note: If you're not logged in as root, you'll need to log out and log in again after installation to complete the docker installation.

Note: This command installs docker and docker compose for Ubuntu. For windows and mac desktop or laptop, please use Docker Desktop. For other OS, please find instructions in Google.

```sh
# Update and upgrade packages
sudo apt-get update
sudo apt-get upgrade -y

### Docker and docker compose prerequisites
sudo apt-get install -y curl
sudo apt-get install -y gnupg
sudo apt-get install -y ca-certificates
sudo apt-get install -y lsb-release

### Download the docker gpg file to Ubuntu
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

### Add Docker and docker compose support to the Ubuntu's packages list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

### Install docker and docker compose on Ubuntu
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo usermod -aG docker $(whoami)

### Verify the Docker and docker compose install on Ubuntu
sudo docker run hello-world
```

(For non-root user) After logged out and logged back in, test if docker is working by running.

```sh
docker ps
```

It should returns an empty container list without having any error. Otherwise, restart your machine if there are errors.

### Clone the Repository

```sh
git clone https://github.com/inkonchain/node
cd node
```

### Copy .env.example to .env

Make a copy of `.env.example` named `.env`.

```sh
cp .env.example .env
```

Open `.env` with your editor of choice

### Mandatory configurations

- **NETWORK_NAME** - Choose which Optimism network layer you want to operate on:
  - `ink-sepolia` - Ink Sepolia (Testnet)
  - `ink-mainnet` - Ink (Mainnet)
- **NODE_TYPE** - Choose the type of node you want to run:
  - `full` (Full node) - A Full node contains a few recent blocks without historical states.
  - `archive` (Archive node) - An Archive node stores the complete history of the blockchain, including historical states.
- **OP_NODE\_\_RPC_ENDPOINT** - Specify the endpoint for the RPC of Layer 1 (e.g., Ethereum mainnet). For instance, you can use the free plan of Quicknode for the Ethereum mainnet.
- **OP_NODE\_\_L1_BEACON** - Specify the beacon endpoint of Layer 1. You can use [QuickNode for the beacon endpoint](https://www.quicknode.com). For example: https://xxx-xxx-xxx.quiknode.pro/db55a3908ba7e4e5756319ffd71ec270b09a7dce
- **OP_NODE\_\_RPC_TYPE** - Specify the service provider for the RPC endpoint you've chosen in the previous step. The available options are:
  - `alchemy` - Alchemy
  - `quicknode` - Quicknode (ETH only)
  - `erigon` - Erigon
  - `basic` - Other providers

### Optional configurations

- **OP_GETH\_\_SYNCMODE** - Specify sync mode for the execution client
  - Unspecified - Use default snap sync for full node and full sync for archive node
  - `snap` - Snap Sync (Default)
  - `full` - Full Sync (For archive node, not recommended for full node)
- **IMAGE_TAG\_\_[...]** - Use custom docker image for specified components.
- **PORT\_\_[...]** - Use custom port for specified components.

## Operating the Node

### Start

```sh
docker compose up -d --build
```

Will start the node in a detached shell (`-d`), meaning the node will continue to run in the background. We recommended to add `--build` to make sure that latest changes are being applied.

### View logs

```sh
docker compose logs -f --tail 10
```

To view logs of all containers.

```sh
docker compose logs <CONTAINER_NAME> -f --tail 10
```

To view logs for a specific container. Most commonly used `<CONTAINER_NAME>` are:

- op-geth
- op-node
- bedrock-init

### Stop

```sh
docker compose down
```

Will shut down the node without wiping any volumes.
You can safely run this command and then restart the node again.

### Restart

```sh
docker compose restart
```

Will restart the node safely with minimal downtime but without upgrading the node.

### Upgrade

Pull the latest updates from GitHub, and Docker Hub and rebuild the container.

```sh
git pull
docker compose pull
docker compose up -d --build
```

Will upgrade your node with minimal downtime.

### Wipe [DANGER]

```sh
docker compose down -v
```

Will shut down the node and WIPE ALL DATA. Proceed with caution!

## Monitoring

### Estimate remaining sync time

Run progress.sh to estimate remaining sync time and speed.

Uses `Cast` command from Foundry tool set. Installation instructions here: https://getfoundry.sh/.

```sh
./progress.sh
```

This will show the sync speed in blocks per minute and the time until sync is completed.

```
Chain ID: 57073
Please wait
Blocks per minute: ...
Hours until sync is completed: ...
```

### Grafana dashboard

Grafana is exposed at [http://localhost:3000](http://localhost:3000) and comes with one pre-loaded dashboard ("Simple Node Dashboard").
Simple Node Dashboard includes basic node information and will tell you if your node ever falls out of sync with the reference L2 node or if a state root fault is detected.

Use the following login details to access the dashboard:

- Username: `admin`
- Password: `ink`

Navigate over to `Dashboards > Manage > Simple Node Dashboard` to see the dashboard, see the following gif if you need help:

![metrics dashboard gif](https://user-images.githubusercontent.com/14298799/171476634-0cb84efd-adbf-4732-9c1d-d737915e1fa7.gif)

## Troubleshooting

### Walking back L1Block with curr=0x0000...:0 next=0x0000...:0

If you experience "walking back L1Block with curr=0x0000...:0 next=0x0000...:0" for a long time after the Ecotone upgrade, consider these fixes:

1. Wait for a few minutes. This issue usually resolves itself after some time.
2. Restart docker compose: `docker compose down` and `docker compose up -d --build`
