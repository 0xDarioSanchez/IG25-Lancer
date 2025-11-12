#!/bin/bash

# Full deployment script for Protocol, Marketplace, and Mock USDC

set -e  # Exit on error

cd /home/dario/BC/ETH/IG/PROJECT/packages/lancer

echo "=========================================="
echo "🚀 Full Contract Deployment"
echo "=========================================="

# Deployer key
DEPLOYER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEPLOYER_ADDR="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
RPC_URL="http://127.0.0.1:8547"

# Buyer and Seller keys
BUYER_KEY="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
BUYER_ADDR=$(cast wallet address --private-key $BUYER_KEY)

SELLER_KEY="0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"
SELLER_ADDR=$(cast wallet address --private-key $SELLER_KEY)

# Judge keys
JUDGE1_KEY="0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba"
JUDGE1_ADDR=$(cast wallet address --private-key $JUDGE1_KEY)

JUDGE2_KEY="0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
JUDGE2_ADDR=$(cast wallet address --private-key $JUDGE2_KEY)

JUDGE3_KEY="0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356"
JUDGE3_ADDR=$(cast wallet address --private-key $JUDGE3_KEY)

JUDGE4_KEY="0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97"
JUDGE4_ADDR=$(cast wallet address --private-key $JUDGE4_KEY)

JUDGE5_KEY="0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6"
JUDGE5_ADDR=$(cast wallet address --private-key $JUDGE5_KEY)

echo "🔑 Addresses:"
echo "  Deployer: $DEPLOYER_ADDR"
echo "  Buyer: $BUYER_ADDR"
echo "  Seller: $SELLER_ADDR"
echo ""

# Fund all accounts
echo "=========================================="
echo "💰 Funding Test Accounts"
echo "=========================================="

for addr in $BUYER_ADDR $SELLER_ADDR $JUDGE1_ADDR $JUDGE2_ADDR $JUDGE3_ADDR $JUDGE4_ADDR $JUDGE5_ADDR; do
    echo "Funding $addr with 100 ETH..."
    cast send $addr --value 100ether --private-key $DEPLOYER_KEY --rpc-url $RPC_URL > /dev/null 2>&1
done

echo "✅ All accounts funded"
echo ""

# Deploy Protocol
echo "=========================================="
echo "📦 Deploying Protocol Contract"
echo "=========================================="

cat > src/lib.rs << 'EOF'
#![cfg_attr(not(feature = "export-abi"), no_main)]
pub mod protocol;
// pub mod marketplace;
// pub mod mocks;
EOF

cat > src/main.rs << 'EOF'
#![cfg_attr(not(feature = "export-abi"), no_main)]

#[cfg(feature = "export-abi")]
fn main() {
    lancer::protocol::print_abi("Apache-2.0", "pragma solidity ^0.8.23;");
}
EOF

cargo build --release --target wasm32-unknown-unknown 2>&1 | grep -E "(Compiling|Finished)"
PROTOCOL_ADDR=$(cargo stylus deploy --no-verify --private-key $DEPLOYER_KEY --endpoint $RPC_URL 2>&1 | grep "deployed code at address" | awk '{print $NF}')
echo "Protocol deployed at: $PROTOCOL_ADDR"
echo ""

# Deploy Marketplace
echo "=========================================="
echo "📦 Deploying Marketplace Contract"
echo "=========================================="

cat > src/lib.rs << 'EOF'
#![cfg_attr(not(feature = "export-abi"), no_main)]
// pub mod protocol;
pub mod marketplace;
// pub mod mocks;
EOF

cat > src/main.rs << 'EOF'
#![cfg_attr(not(feature = "export-abi"), no_main)]

#[cfg(feature = "export-abi")]
fn main() {
    lancer::marketplace::print_abi("Apache-2.0", "pragma solidity ^0.8.23;");
}
EOF

cargo build --release --target wasm32-unknown-unknown 2>&1 | grep -E "(Compiling|Finished)"
MARKETPLACE_ADDR=$(cargo stylus deploy --no-verify --private-key $DEPLOYER_KEY --endpoint $RPC_URL 2>&1 | grep "deployed code at address" | awk '{print $NF}')
echo "Marketplace deployed at: $MARKETPLACE_ADDR"
echo ""

# Deploy Mock USDC
echo "=========================================="
echo "📦 Deploying Mock USDC Contract"
echo "=========================================="

cat > src/lib.rs << 'EOF'
#![cfg_attr(not(feature = "export-abi"), no_main)]
// pub mod protocol;
// pub mod marketplace;
pub mod mocks;
EOF

cat > src/main.rs << 'EOF'
#![cfg_attr(not(feature = "export-abi"), no_main)]

#[cfg(feature = "export-abi")]
fn main() {
    lancer::mocks::mock_usdc::print_abi("Apache-2.0", "pragma solidity ^0.8.23;");
}
EOF

cargo build --release --target wasm32-unknown-unknown 2>&1 | grep -E "(Compiling|Finished)"
USDC_ADDR=$(cargo stylus deploy --no-verify --private-key $DEPLOYER_KEY --endpoint $RPC_URL 2>&1 | grep "deployed code at address" | awk '{print $NF}')
echo "Mock USDC deployed at: $USDC_ADDR"
echo ""

# Initialize contracts
echo "=========================================="
echo "⚙️  Initializing Contracts"
echo "=========================================="

echo "Initializing Mock USDC..."
cast send $USDC_ADDR "init(address)" $DEPLOYER_ADDR --private-key $DEPLOYER_KEY --rpc-url $RPC_URL --gas-limit 5000000 > /dev/null 2>&1
echo "✅ Mock USDC initialized"

echo "Initializing Protocol..."
cast send $PROTOCOL_ADDR "init(address,address)" $DEPLOYER_ADDR $USDC_ADDR --private-key $DEPLOYER_KEY --rpc-url $RPC_URL --gas-limit 5000000 > /dev/null 2>&1
cast send $PROTOCOL_ADDR "updateNumberOfVotes(uint8)" 3 --private-key $DEPLOYER_KEY --rpc-url $RPC_URL --gas-limit 5000000 > /dev/null 2>&1
echo "✅ Protocol initialized (3 votes required)"

echo "Initializing Marketplace..."
cast send $MARKETPLACE_ADDR "init(address,uint8,address,address)" $DEPLOYER_ADDR 5 $USDC_ADDR $PROTOCOL_ADDR --private-key $DEPLOYER_KEY --rpc-url $RPC_URL --gas-limit 5000000 > /dev/null 2>&1
echo "✅ Marketplace initialized"
echo ""

# Mint USDC to buyer
echo "=========================================="
echo "💵 Minting USDC"
echo "=========================================="

echo "Minting 100 USDC to buyer..."
cast send $USDC_ADDR "mint(address,uint256)" $BUYER_ADDR 100000000 --private-key $DEPLOYER_KEY --rpc-url $RPC_URL --gas-limit 5000000 > /dev/null 2>&1
BUYER_BALANCE=$(cast call $USDC_ADDR "balanceOf(address)(uint256)" $BUYER_ADDR --rpc-url $RPC_URL)
echo "✅ Buyer USDC balance: $BUYER_BALANCE (100 USDC with 6 decimals)"
echo ""

# Save deployment info
echo "=========================================="
echo "💾 Saving Deployment Info"
echo "=========================================="

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
  "rpc_url": "$RPC_URL",
  "chain_id": 412346
}
EOF

echo "✅ Deployment info saved to build/stylus-deployment-info.json"
echo ""

echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo "Protocol:    $PROTOCOL_ADDR"
echo "Marketplace: $MARKETPLACE_ADDR"
echo "Mock USDC:   $USDC_ADDR"
echo "=========================================="
