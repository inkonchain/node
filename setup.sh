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

# Ask if the user wants to fetch the latest snapshot
read -p "Do you want to fetch the latest snapshot? [y/N]: " fetch_snapshot
echo ""

if [[ "$fetch_snapshot" == "y" || "$fetch_snapshot" == "Y" ]]; then
  SNAPSHOT_FILE_PATH=$(curl -s https://storage.googleapis.com/raas-op-geth-snapshots-d2a56/datadir-archive/latest)
  SNAPSHOT_FILE_NAME=${SNAPSHOT_FILE_PATH##*/}

  echo -e "${GRAY}Fetching the latest snapshot... ${ITALIC}(will take a few minutes...) ${NC}"
  wget https://storage.googleapis.com/raas-op-geth-snapshots-d2a56/datadir-archive/$SNAPSHOT_FILE_PATH
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}↳ Snapshot successfully fetched as $SNAPSHOT_FILE_NAME.${NC}\n"
  else
    echo -e "${RED}↳ Error fetching the snapshot.${NC}\n"
    exit 1
  fi

  echo -e "${GRAY}Fetching the snapshot checksum...${NC}"
  wget https://storage.googleapis.com/raas-op-geth-snapshots-d2a56/datadir-archive/$SNAPSHOT_FILE_PATH.sha256
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}↳ Checksum successfully fetched as $SNAPSHOT_FILE_NAME.sha256${NC}\n"
  else
    echo -e "${RED}↳ Error fetching the checksum.${NC}\n"
    exit 1
  fi

  echo -e "${GRAY}Verifying the snapshot checksum... ${ITALIC}(can take a few minutes...)${NC}"
  shasum -a 256 -c $SNAPSHOT_FILE_NAME.sha256
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}↳ Checksum verification passed.${NC}\n"
  else
    echo -e "${RED}↳ Checksum verification failed.${NC}\n"
    exit 1
  fi

  echo -e "${GRAY}Renaming the snapshot to $RENAMED_SNAPSHOT_FILE_NAME${NC}"
  mv $SNAPSHOT_FILE_NAME $RENAMED_SNAPSHOT_FILE_NAME
    if [ $? -eq 0 ]; then
    echo -e "${GREEN}↳ Snapshot renamed properly to $RENAMED_SNAPSHOT_FILE_NAME.${NC}\n"
  else
    echo -e "${RED}↳ Failed to rename the snapshot.${NC}\n"
    exit 1
  fi
else
  echo -e "${BLUE}Skipping snapshot fetch.${NC}\n"
fi

# Create the `var` directory structure
echo -e "${GRAY}Creating var/secrets directory structure...${NC}"
mkdir -p var/secrets
if [ $? -eq 0 ]; then
  echo -e "${GREEN}↳ Directory structure created.${NC}\n"
else
  echo -e "${RED}↳ Error creating directory structure.${NC}\n"
  exit 1
fi

# Generate the secret for the engine API secure communication
echo -e "${GRAY}Generating secret for the engine API secure communication...${NC}"
openssl rand -hex 32 > var/secrets/jwt.txt
if [ $? -eq 0 ]; then
  echo -e "${GREEN}↳ Secret generated and saved to var/secrets/jwt.txt.${NC}\n"
else
  echo -e "${RED}↳ Error generating secret.${NC}\n"
  exit 1
fi

# Check if RENAMED_SNAPSHOT_FILE_NAME and geth exist and handle accordingly
if [ -f $RENAMED_SNAPSHOT_FILE_NAME ]; then
  if [ -d geth ]; then
    echo -e "${WHITE}$RENAMED_SNAPSHOT_FILE_NAME snapshot detected at the root, but geth already exists.${NC}"
    read -p "Do you want to wipe the existing geth and reset from snapshot? [y/N] " response
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
      echo -e "${GRAY}Removing existing geth directory...${NC}"
      rm -rf ./geth
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}↳ Existing geth directory removed.${NC}\n"
      else
        echo -e "${RED}↳ Error removing existing geth directory.${NC}\n"
        exit 1
      fi
      echo -e "${GRAY}Decompressing and extracting $RENAMED_SNAPSHOT_FILE_NAME... ${ITALIC}(will take a few minutes...)${NC}"
      tar -xzf $RENAMED_SNAPSHOT_FILE_NAME
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}↳ Decompression and extraction complete.${NC}\n"
      else
        echo -e "${RED}↳ Error during decompression and extraction.${NC}\n"
        exit 1
      fi
    else
      echo -e "Preserving existing geth directory.${NC}\n"
    fi
  else
    echo -e "${GRAY}geth directory not found. Decompressing and extracting $RENAMED_SNAPSHOT_FILE_NAME...${NC}"
    tar -xzf $RENAMED_SNAPSHOT_FILE_NAME
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Decompression and extraction complete.${NC}\n"
    else
      echo -e "${RED}Error during decompression and extraction.${NC}\n"
      exit 1
    fi
  fi
else
  echo -e "${RED}$RENAMED_SNAPSHOT_FILE_NAME not found. Skipping decompression.${NC}\n"
fi

echo -e "${WHITE}The Ink Node is ready to be started. Run it with:${NC}\n${BLUE}  docker compose up${GRAY} # --build to force rebuild the images ${NC}"
