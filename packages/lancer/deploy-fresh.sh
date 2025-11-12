#!/bin/bash
set -e

echo "🚀 Deploying all contracts to fresh blockchain..."

# Deploy Protocol
echo "📝 Deploying Protocol..."
PROTOCOL_ADDR=$(cargo stylus deploy --no-verify \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --wasm-file lancer-protocol.wasm \
  --endpoint http://127.0.0.1:8547 2>&1 | grep "deployed code at address" | awk '{print $NF}')
echo "✅ Protocol deployed: $PROTOCOL_ADDR"

# Deploy Marketplace
echo "📝 Deploying Marketplace..."
MARKETPLACE_ADDR=$(cargo stylus deploy --no-verify \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --wasm-file lancer-marketplace.wasm \
  --endpoint http://127.0.0.1:8547 2>&1 | grep "deployed code at address" | awk '{print $NF}')
echo "✅ Marketplace deployed: $MARKETPLACE_ADDR"

# Deploy Mock USDC
echo "📝 Deploying Mock USDC..."
USDC_ADDR=$(cargo stylus deploy --no-verify \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --wasm-file lancer-usdc.wasm \
  --endpoint http://127.0.0.1:8547 2>&1 | grep "deployed code at address" | awk '{print $NF}')
echo "✅ Mock USDC deployed: $USDC_ADDR"

# Update deployment info JSON
cat > build/stylus-deployment-info.json << EOF
{
  "protocol_contract": {
    "address": "$PROTOCOL_ADDR"
  },
  "marketplace_contract": {
    "address": "$MARKETPLACE_ADDR"
  },
  "usdc_contract": {
    "address": "$USDC_ADDR"
  },
  "rpc_url": "http://127.0.0.1:8547",
  "chain_id": 412346
}
EOF

echo "✅ Updated deployment info JSON"

# Initialize contracts
echo "🔧 Initializing contracts..."

DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
BUYER=0x90F79bf6EB2c4f870365E785982E1f101E93b906

# Initialize Protocol (owner, usdc)
echo "  - Initializing Protocol..."
cast send "$PROTOCOL_ADDR" "init(address,address)" "$DEPLOYER" "$USDC_ADDR" \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://127.0.0.1:8547 > /dev/null

# Update votes to 3
echo "  - Updating votes to 3..."
cast send "$PROTOCOL_ADDR" "updateNumberOfVotes(uint8)" 3 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://127.0.0.1:8547 > /dev/null

# Initialize Marketplace (owner, fee_percent, usdc, protocol)
echo "  - Initializing Marketplace..."
cast send "$MARKETPLACE_ADDR" "init(address,uint8,address,address)" "$DEPLOYER" 5 "$USDC_ADDR" "$PROTOCOL_ADDR" \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://127.0.0.1:8547 > /dev/null

# Initialize USDC
echo "  - Initializing USDC..."
cast send "$USDC_ADDR" "init(address)" "$DEPLOYER" \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://127.0.0.1:8547 > /dev/null

# Mint 100 USDC to buyer (100000000 with 6 decimals)
echo "  - Minting 100 USDC to buyer..."
cast send "$USDC_ADDR" "mint(address,uint256)" "$BUYER" 100000000 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://127.0.0.1:8547 > /dev/null

echo "✅ All contracts initialized!"
echo ""
echo "📋 Deployment Summary:"
echo "  Protocol:    $PROTOCOL_ADDR"
echo "  Marketplace: $MARKETPLACE_ADDR"
echo "  Mock USDC:   $USDC_ADDR"
echo ""
echo "Ready to run tests: ./test-contracts.sh"
