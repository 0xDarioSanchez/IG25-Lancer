#!/bin/bash

# Simple script to just run the Nitro dev node (contracts already deployed)

echo "Starting Nitro dev node..."
docker run --rm --name nitro-dev -p 8547:8547 \
  offchainlabs/nitro-node:v3.2.1-d81324d \
  --dev \
  --http.addr 0.0.0.0 \
  --http.api=net,web3,eth,debug \
  --http.corsdomain="*"
