#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
GRAY='\033[1;30m'
WHITE='\033[1;37m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
ITALIC='\033[3m'

RENAMED_SNAPSHOT_FILE_NAME='geth.tar.gz'

# Function to validate Sepolia RPC URL
validate_sepolia_url() {
    local url=$1
    echo -e "${GRAY}Validating RPC endpoint... ${ITALIC}(checking chain ID)${NC}"
    local chain_id=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        "$url" | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)

    if [ "$chain_id" = "0xaa36a7" ]; then
        echo -e "${GREEN}↳ Valid Sepolia RPC endpoint detected ✅${NC}\n"
        return 0
    else
        echo -e "${RED}↳ Invalid chain ID. Expected Sepolia (0xaa36a7) ❌${NC}\n"
        return 1
    fi
}

# Function to validate Beacon API endpoint
validate_beacon_api() {
    local url=$1
    echo -e "${GRAY}Validating Beacon API support... ${ITALIC}(checking /eth/v1/node/version)${NC}"
    local response=$(curl -s -f "${url}/eth/v1/node/version" -H 'accept: application/json')
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}↳ Beacon API support confirmed ✅${NC}\n"
        return 0
    else
        echo -e "${RED}↳ Beacon API not supported on this endpoint ❌${NC}\n"
        return 1
    fi
}

# Check if .env exists and configure L1 URLs
echo -e "\n${WHITE}Welcome to the Ink Sepolia Node Setup Script! 🚀${NC}\n"

if [ -f .env ] && grep -q "L1_RPC_URL" .env; then
    # Get existing URL from .env
    existing_url=$(grep "L1_RPC_URL" .env | cut -d'=' -f2)
    echo -e "${GRAY}Found existing configuration in${NC} ${WHITE}.env${NC}${GRAY}. Validating...${NC}\n"

    # Validate existing configuration
    if validate_sepolia_url "$existing_url" && validate_beacon_api "$existing_url"; then
        echo -e "${GREEN}Existing configuration is valid ✨${NC}\n"
    else
        echo -e "${RED}Existing configuration is invalid. Let's reconfigure it ⚠️${NC}\n"
        # Remove the existing .env file
        rm .env
    fi
fi

if [ ! -f .env ] || ! grep -q "L1_RPC_URL" .env; then
    echo -e "${WHITE}We need to configure your Sepolia L1 URL.${NC}"
    echo -e "${GRAY}Please provide a URL that supports both:${NC}"
    echo -e "${GRAY}  • JSON-RPC (for regular Ethereum calls)${NC}"
    echo -e "${GRAY}  • Beacon API (for consensus layer interaction)${NC}\n"

    while true; do
        echo -e "${WHITE}Enter your Sepolia L1 URL:${NC}"
        echo -n "Url: "
        read rpc_url
        echo ""

        # Remove trailing slash if present
        rpc_url=${rpc_url%/}

        # Validate RPC endpoint
        if ! validate_sepolia_url "$rpc_url"; then
            echo -e "${RED}Please provide a valid Sepolia L1 URL and try again ❌${NC}\n"
            continue
        fi

        # Validate Beacon API endpoint
        if ! validate_beacon_api "$rpc_url"; then
            echo -e "${RED}Please provide a URL with Beacon API support and try again ❌${NC}\n"
            continue
        fi

        # If both validations pass, create/update .env file
        echo "L1_RPC_URL=$rpc_url" > .env
        echo "L1_BEACON_URL=$rpc_url" >> .env
        echo -e "${GREEN}Success! Your Sepolia L1 URL has been configured ✨${NC}"
        echo -e "${GRAY}Configuration saved to${NC} ${WHITE}.env${NC} ${GRAY}file 📝${NC}\n"
        break
    done
fi

# Ask if the user wants to fetch the latest snapshot
read -p "Do you want to fetch the latest snapshot? [y/N]: " fetch_snapshot
echo ""

if [[ "$fetch_snapshot" == "y" || "$fetch_snapshot" == "Y" ]]; then
  SNAPSHOT_FILE_PATH=$(curl -s https://storage.googleapis.com/raas-op-geth-snapshots-d2a56/datadir-archive/latest)
  SNAPSHOT_FILE_NAME=${SNAPSHOT_FILE_PATH##*/}

  echo -e "${GRAY}Fetching the latest snapshot... ${ITALIC}(will take a few minutes...) ${NC}"
  wget https://storage.googleapis.com/raas-op-geth-snapshots-d2a56/datadir-archive/$SNAPSHOT_FILE_PATH
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}↳ Snapshot successfully fetched as $SNAPSHOT_FILE_NAME ✅${NC}\n"
  else
    echo -e "${RED}↳ Error fetching the snapshot ❌${NC}\n"
    exit 1
  fi

  echo -e "${GRAY}Fetching the snapshot checksum...${NC}"
  wget https://storage.googleapis.com/raas-op-geth-snapshots-d2a56/datadir-archive/$SNAPSHOT_FILE_PATH.sha256
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}↳ Checksum successfully fetched ✅${NC}\n"
  else
    echo -e "${RED}↳ Error fetching the checksum ❌${NC}\n"
    exit 1
  fi

  echo -e "${GRAY}Verifying the snapshot checksum... ${ITALIC}(can take a few minutes...)${NC}"
  shasum -a 256 -c $SNAPSHOT_FILE_NAME.sha256
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}↳ Checksum verification passed ✅${NC}\n"
  else
    echo -e "${RED}↳ Checksum verification failed ❌${NC}\n"
    exit 1
  fi

  echo -e "${GRAY}Renaming the snapshot to $RENAMED_SNAPSHOT_FILE_NAME${NC}"
  mv $SNAPSHOT_FILE_NAME $RENAMED_SNAPSHOT_FILE_NAME
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}↳ Snapshot renamed successfully ✅${NC}\n"
  else
    echo -e "${RED}↳ Failed to rename the snapshot ❌${NC}\n"
    exit 1
  fi
else
  echo -e "${BLUE}Skipping snapshot fetch ⏩${NC}\n"
fi

# Create the `var` directory structure with proper permissions
echo -e "${GRAY}Creating var/secrets directory structure...${NC}"
mkdir -p var/secrets
if [ $? -eq 0 ]; then
  chmod 777 var
  chmod 777 var/secrets
  echo -e "${GREEN}↳ Directory structure created with proper permissions ✅${NC}\n"
else
  echo -e "${RED}↳ Error creating directory structure ❌${NC}\n"
  exit 1
fi

# Generate the secret for the engine API secure communication
echo -e "${GRAY}Generating secret for the engine API secure communication...${NC}"
openssl rand -hex 32 > var/secrets/jwt.txt
if [ $? -eq 0 ]; then
  chmod 666 var/secrets/jwt.txt
  echo -e "${GREEN}↳ Secret generated and saved with proper permissions 🔑${NC}\n"
else
  echo -e "${RED}↳ Error generating secret ❌${NC}\n"
  exit 1
fi

# Check if RENAMED_SNAPSHOT_FILE_NAME and geth exist and handle accordingly
if [ -f $RENAMED_SNAPSHOT_FILE_NAME ]; then
  if [ -d geth ]; then
    echo -e "${WHITE}$RENAMED_SNAPSHOT_FILE_NAME snapshot detected at the root, but geth already exists 🔍${NC}"
    read -p "Do you want to wipe the existing geth and reset from snapshot? [y/N] " response
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
      echo -e "${GRAY}Removing existing geth directory...${NC}"
      rm -rf ./geth
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}↳ Existing geth directory removed ✅${NC}\n"
      else
        echo -e "${RED}↳ Error removing existing geth directory ❌${NC}\n"
        exit 1
      fi
      echo -e "${GRAY}Decompressing and extracting $RENAMED_SNAPSHOT_FILE_NAME... ${ITALIC}(will take a few minutes...)${NC}"
      tar -xzf $RENAMED_SNAPSHOT_FILE_NAME
      if [ $? -eq 0 ]; then
        chmod -R 777 geth
        echo -e "${GREEN}↳ Decompression and extraction complete ✅${NC}\n"
      else
        echo -e "${RED}↳ Error during decompression and extraction ❌${NC}\n"
        exit 1
      fi
    else
      echo -e "${BLUE}Preserving existing geth directory ⏩${NC}\n"
      chmod -R 777 geth
    fi
  else
    echo -e "${GRAY}geth directory not found. Decompressing and extracting $RENAMED_SNAPSHOT_FILE_NAME...${NC}"
    tar -xzf $RENAMED_SNAPSHOT_FILE_NAME
    if [ $? -eq 0 ]; then
      chmod -R 777 geth
      echo -e "${GREEN}↳ Decompression and extraction complete ✅${NC}\n"
    else
      echo -e "${RED}↳ Error during decompression and extraction ❌${NC}\n"
      exit 1
    fi
  fi
else
  echo -e "${BLUE}$RENAMED_SNAPSHOT_FILE_NAME not found. Skipping decompression ⏩${NC}\n"
  if [ -d geth ]; then
    chmod -R 777 geth
  fi
fi
# Request for deleting snapshot archive
read -p "Do you want to remove the snapshot archive? [y/N]: " remove_archive
if [[ "$remove_archive" == "y" || "$remove_archive" == "Y" ]]; then
  echo -e "${GRAY}Removing the snapshot archive...${NC}"
  rm -f $RENAMED_SNAPSHOT_FILE_NAME
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}↳ Snapshot archive removed successfully ✅${NC}\n"
  else
    echo -e "${RED}↳ Error removing snapshot archive ❌${NC}\n"
    exit 1
  fi
else
  echo -e "${BLUE}Skipping archive removal ⏩${NC}\n"
fi
# Final permission check
echo -e "${GRAY}Performing final permission check...${NC}"
chmod -R 777 geth 2>/dev/null || true
chmod -R 777 var
chmod 666 var/secrets/jwt.txt
echo -e "${GREEN}↳ Permissions verified ✅${NC}\n"

echo -e "${WHITE}The Ink Node is ready to be started 🎉 Run it with:${NC}\n${BLUE}  docker compose up${GRAY} # --build to force rebuild the images ${NC}\n"
