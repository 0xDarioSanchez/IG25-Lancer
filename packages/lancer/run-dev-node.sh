#!/bin/bash

# Start Nitro dev node in the background
echo "Starting Nitro dev node..."
docker run --rm --name nitro-dev -p 8547:8547 offchainlabs/nitro-node:v3.2.1-d81324d --dev --http.addr 0.0.0.0 --http.api=net,web3,eth,debug --http.corsdomain="*" &

# Wait for the node to initialize
echo "Waiting for the Nitro node to initialize..."

until [[ "$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  http://127.0.0.1:8547)" == *"result"* ]]; do
    sleep 0.1
done

# Check if node is running
curl_output=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  http://127.0.0.1:8547)

if [[ "$curl_output" == *"result"* ]]; then
  echo "Nitro node is running!"
else
  echo "Failed to start Nitro node."
  exit 1
fi

# Make the caller a chain owner
echo "Setting chain owner to pre-funded dev account..."
cast send 0x00000000000000000000000000000000000000FF "becomeChainOwner()" \
  --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 \
  --rpc-url http://127.0.0.1:8547

# Deploy Cache Manager Contract
echo "Deploying Cache Manager contract..."
cache_deploy_output=$(cast send --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 \
  --rpc-url http://127.0.0.1:8547 \
  --create 0x60a06040523060805234801561001457600080fd5b50608051611d1c61003060003960006105260152611d1c6000f3fe)

# Extract cache manager contract address using robust pattern
cache_manager_address=$(echo "$cache_deploy_output" | grep "contractAddress" | grep -oE '0x[a-fA-F0-9]{40}')

if [[ -z "$cache_manager_address" ]]; then
  echo "Error: Failed to extract Cache Manager contract address. Full output:"
  echo "$cache_deploy_output"
  exit 1
fi

echo "Cache Manager contract deployed at address: $cache_manager_address"

# Register the deployed Cache Manager contract
echo "Registering Cache Manager contract as a WASM cache manager..."
registration_output=$(cast send --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 \
  --rpc-url http://127.0.0.1:8547 \
  0x0000000000000000000000000000000000000070 \
  "addWasmCacheManager(address)" "$cache_manager_address")

if [[ "$registration_output" == *"error"* ]]; then
  echo "Failed to register Cache Manager contract. Registration output:"
  echo "$registration_output"
  exit 1
fi

echo "Cache Manager deployed and registered successfully."

############################################
# DEPLOY PROTOCOL CONTRACT
############################################
echo "=========================================="
echo "Deploying Protocol Contract..."
echo "=========================================="

# Enable protocol module in lib.rs
sed -i 's|^// pub mod marketplace;|// pub mod marketplace;|' src/lib.rs
sed -i 's|^pub mod protocol;|pub mod protocol;|' src/lib.rs

# Update main.rs to export protocol ABI
sed -i 's|^    // lancer::marketplace::print_abi|    // lancer::marketplace::print_abi|' src/main.rs
sed -i 's|^    lancer::protocol::print_abi|    lancer::protocol::print_abi|' src/main.rs

protocol_deploy_output=$(cargo stylus deploy -e http://127.0.0.1:8547 --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 --no-verify 2>&1)

if [[ $? -ne 0 ]]; then
    echo "Error: Protocol contract deployment failed"
    echo "Deploy output: $protocol_deploy_output"
    exit 1
fi

protocol_tx=$(echo "$protocol_deploy_output" | grep -oE '0x[a-fA-F0-9]{64}' | head -1)
protocol_address=$(echo "$protocol_deploy_output" | grep -oE '0x[a-fA-F0-9]{40}' | head -1)

if [[ -z "$protocol_tx" || -z "$protocol_address" ]]; then
    echo "Error: Could not extract Protocol contract deployment info"
    echo "Deploy output: $protocol_deploy_output"
    exit 1
fi

echo "✅ Protocol Contract deployed successfully!"
echo "   Address: $protocol_address"
echo "   TX Hash: $protocol_tx"

# Generate Protocol ABI
echo "Generating Protocol ABI..."
cargo stylus export-abi > build/protocol.abi
echo "✅ Protocol ABI saved to build/protocol.abi"

############################################
# DEPLOY MARKETPLACE CONTRACT
############################################
echo ""
echo "=========================================="
echo "Deploying Marketplace Contract..."
echo "=========================================="

# Enable marketplace module, disable protocol in lib.rs
sed -i 's|^// pub mod marketplace;|pub mod marketplace;|' src/lib.rs
sed -i 's|^pub mod protocol;|// pub mod protocol;|' src/lib.rs

# Update main.rs to export marketplace ABI
sed -i 's|^    lancer::protocol::print_abi|    // lancer::protocol::print_abi|' src/main.rs
sed -i 's|^    // lancer::marketplace::print_abi|    lancer::marketplace::print_abi|' src/main.rs

marketplace_deploy_output=$(cargo stylus deploy -e http://127.0.0.1:8547 --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 --no-verify 2>&1)

if [[ $? -ne 0 ]]; then
    echo "Error: Marketplace contract deployment failed"
    echo "Deploy output: $marketplace_deploy_output"
    exit 1
fi

marketplace_tx=$(echo "$marketplace_deploy_output" | grep -oE '0x[a-fA-F0-9]{64}' | head -1)
marketplace_address=$(echo "$marketplace_deploy_output" | grep -oE '0x[a-fA-F0-9]{40}' | head -1)

if [[ -z "$marketplace_tx" || -z "$marketplace_address" ]]; then
    echo "Error: Could not extract Marketplace contract deployment info"
    echo "Deploy output: $marketplace_deploy_output"
    exit 1
fi

echo "✅ Marketplace Contract deployed successfully!"
echo "   Address: $marketplace_address"
echo "   TX Hash: $marketplace_tx"

# Generate Marketplace ABI
echo "Generating Marketplace ABI..."
cargo stylus export-abi > build/marketplace.abi
echo "✅ Marketplace ABI saved to build/marketplace.abi"

# Restore lib.rs to default (protocol enabled)
sed -i 's|^pub mod marketplace;|// pub mod marketplace;|' src/lib.rs
sed -i 's|^// pub mod protocol;|pub mod protocol;|' src/lib.rs

# Restore main.rs to default (protocol enabled)
sed -i 's|^    lancer::marketplace::print_abi|    // lancer::marketplace::print_abi|' src/main.rs
sed -i 's|^    // lancer::protocol::print_abi|    lancer::protocol::print_abi|' src/main.rs

############################################
# SAVE DEPLOYMENT INFO
############################################
mkdir -p build

echo "{
  \"network\": \"nitro-dev\",
  \"rpc_url\": \"http://127.0.0.1:8547\",
  \"deployment_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"cache_manager_address\": \"$cache_manager_address\",
  \"protocol_contract\": {
    \"address\": \"$protocol_address\",
    \"transaction_hash\": \"$protocol_tx\",
    \"abi_file\": \"build/protocol.abi\"
  },
  \"marketplace_contract\": {
    \"address\": \"$marketplace_address\",
    \"transaction_hash\": \"$marketplace_tx\",
    \"abi_file\": \"build/marketplace.abi\"
  }
}" > build/stylus-deployment-info.json

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "=========================================="
echo "Protocol Contract:    $protocol_address"
echo "Marketplace Contract: $marketplace_address"
echo "Deployment info saved to: build/stylus-deployment-info.json"
echo "=========================================="

# Keep the script running but also monitor the Nitro node
while true; do
  if ! docker ps | grep -q nitro-dev; then
    echo "Nitro node container stopped unexpectedly"
    exit 1
  fi
  sleep 5
done