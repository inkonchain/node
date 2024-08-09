#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
GRAY='\033[1;30m'
WHITE='\033[1;37m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if geth.tar.lz4 and geth-data exist and handle accordingly
if [ -f geth.tar.lz4 ]; then
  if [ -d geth-data ]; then
    echo -e "${WHITE}geth.tar.lz4 snapshot detected at the root, but geth-data already exists.${NC}"
    read -p "Do you want to wipe the existing geth-data and reset from snapshot? [y/N] " response
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
      echo -e "${GRAY}Removing existing geth-data directory...${NC}"
      rm -rf ./geth-data
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}↳ Existing geth-data directory removed.${NC}\n"
      else
        echo -e "${RED}↳ Error removing existing geth-data directory.${NC}\n"
        exit 1
      fi
      echo -e "${GRAY}Decompressing and extracting geth.tar.lz4...${NC}"
      lz4 -d geth.tar.lz4 -c | tar -x
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}↳ Decompression and extraction complete.${NC}\n"
      else
        echo -e "${RED}↳ Error during decompression and extraction.${NC}\n"
        exit 1
      fi
    else
      echo -e "Preserving existing geth-data directory.${NC}\n"
    fi
  else
    echo -e "${GRAY}geth-data directory not found. Decompressing and extracting geth.tar.lz4...${NC}"
    lz4 -d geth.tar.lz4 -c | tar -x
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Decompression and extraction complete.${NC}\n"
    else
      echo -e "${RED}Error during decompression and extraction.${NC}\n"
      exit 1
    fi
  fi
else
  echo -e "${RED}geth.tar.lz4 not found. Skipping decompression.${NC}\n"
fi

echo -e "${WHITE}The Ink Node is ready to be started. Run it with:${NC}\n${BLUE}  docker compose up${GRAY} # --build to force rebuild the images ${NC}"
