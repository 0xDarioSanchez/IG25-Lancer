#!/bin/bash

# Test script for Lancer Protocol and Marketplace contracts
# This script tests the full workflow: user registration, deal creation, dispute, and voting

set -e  # Exit on error

# Load deployment info
DEPLOYMENT_FILE="build/stylus-deployment-info.json"

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "❌ Deployment file not found. Please run ./run-dev-node.sh first"
    exit 1
fi

# Extract contract addresses
PROTOCOL_ADDRESS=$(jq -r '.protocol_contract.address' "$DEPLOYMENT_FILE")
MARKETPLACE_ADDRESS=$(jq -r '.marketplace_contract.address' "$DEPLOYMENT_FILE")
RPC_URL=$(jq -r '.rpc_url' "$DEPLOYMENT_FILE")

echo "=========================================="
echo "🧪 Testing Lancer Contracts"
echo "=========================================="
echo "Protocol Contract:    $PROTOCOL_ADDRESS"
echo "Marketplace Contract: $MARKETPLACE_ADDRESS"
echo "RPC URL:              $RPC_URL"
echo ""

# Test accounts (from Nitro dev node)
OWNER_KEY="0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659"
OWNER_ADDR=$(cast wallet address --private-key $OWNER_KEY)

BUYER_KEY="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
BUYER_ADDR=$(cast wallet address --private-key $BUYER_KEY)

SELLER_KEY="0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"
SELLER_ADDR=$(cast wallet address --private-key $SELLER_KEY)

JUDGE1_KEY="0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba"
JUDGE1_ADDR=$(cast wallet address --private-key $JUDGE1_KEY)

JUDGE2_KEY="0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
JUDGE2_ADDR=$(cast wallet address --private-key $JUDGE2_KEY)

JUDGE3_KEY="0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356"
JUDGE3_ADDR=$(cast wallet address --private-key $JUDGE3_KEY)

# USDC Mock Token (using a placeholder address for testing)
USDC_ADDRESS="0x1111111111111111111111111111111111111111"  # Mock USDC

echo "=========================================="
echo "📋 STEP 0: Fund Test Accounts"
echo "=========================================="

echo "Funding Buyer: $BUYER_ADDR"
cast send $BUYER_ADDR \
    --value 10ether \
    --private-key $OWNER_KEY \
    --rpc-url $RPC_URL

echo "Funding Seller: $SELLER_ADDR"
cast send $SELLER_ADDR \
    --value 10ether \
    --private-key $OWNER_KEY \
    --rpc-url $RPC_URL

echo "Funding Judge 1: $JUDGE1_ADDR"
cast send $JUDGE1_ADDR \
    --value 10ether \
    --private-key $OWNER_KEY \
    --rpc-url $RPC_URL

echo "Funding Judge 2: $JUDGE2_ADDR"
cast send $JUDGE2_ADDR \
    --value 10ether \
    --private-key $OWNER_KEY \
    --rpc-url $RPC_URL

echo "Funding Judge 3: $JUDGE3_ADDR"
cast send $JUDGE3_ADDR \
    --value 10ether \
    --private-key $OWNER_KEY \
    --rpc-url $RPC_URL

echo "✅ All accounts funded"
echo ""

echo "=========================================="
echo "📋 STEP 1: Initialize Contracts"
echo "=========================================="

echo "Initializing Protocol Contract..."
echo "  Owner: $OWNER_ADDR"
echo "  USDC Token: $USDC_ADDRESS"

cast send $PROTOCOL_ADDRESS \
    "init(address,address)" \
    $OWNER_ADDR $USDC_ADDRESS \
    --private-key $OWNER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Initializing Marketplace Contract..."
echo "  Owner: $OWNER_ADDR"
echo "  Fee: 5%"
echo "  USDC Token: $USDC_ADDRESS"
echo "  Protocol: $PROTOCOL_ADDRESS"

cast send $MARKETPLACE_ADDRESS \
    "init(address,uint8,address,address)" \
    $OWNER_ADDR 5 $USDC_ADDRESS $PROTOCOL_ADDRESS \
    --private-key $OWNER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ Contracts initialized"
echo ""

echo "=========================================="
echo "📋 STEP 2: Register Judges in Protocol"
echo "=========================================="

echo "Registering Judge 1: $JUDGE1_ADDR"
cast send $PROTOCOL_ADDRESS \
    "registerAsJudge()" \
    --private-key $JUDGE1_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000 || echo "  (Judge 1 already registered)"

echo "Registering Judge 2: $JUDGE2_ADDR"
cast send $PROTOCOL_ADDRESS \
    "registerAsJudge()" \
    --private-key $JUDGE2_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000 || echo "  (Judge 2 already registered)"

echo "Registering Judge 3: $JUDGE3_ADDR"
cast send $PROTOCOL_ADDRESS \
    "registerAsJudge()" \
    --private-key $JUDGE3_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000 || echo "  (Judge 3 already registered)"

echo "✅ Judges registered or already exist"
echo ""

echo "=========================================="
echo "📋 STEP 3: Register Users in Marketplace"
echo "=========================================="

echo "Registering Buyer: $BUYER_ADDR"
cast send $MARKETPLACE_ADDRESS \
    "registerUser(bool,bool,bool)" \
    true false false \
    --private-key $BUYER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Registering Seller: $SELLER_ADDR"
cast send $MARKETPLACE_ADDRESS \
    "registerUser(bool,bool,bool)" \
    false true false \
    --private-key $SELLER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ Users registered"
echo ""

echo "=========================================="
echo "📋 STEP 4: Create Deal"
echo "=========================================="

DEAL_AMOUNT="1000000"  # 1 USDC (6 decimals)
DEAL_DURATION="7"      # 7 days

echo "Creating deal: $DEAL_AMOUNT USDC for $DEAL_DURATION days"
echo "Buyer: $BUYER_ADDR"
echo "Seller: $SELLER_ADDR"

DEAL_TX=$(cast send $MARKETPLACE_ADDRESS \
    "createDeal(address,uint256,uint64)" \
    $SELLER_ADDR $DEAL_AMOUNT $DEAL_DURATION \
    --private-key $BUYER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000 \
    --json | jq -r '.transactionHash')

echo "Deal created! TX: $DEAL_TX"

# Get the deal ID from events (assuming it's deal ID 0 for first deal)
DEAL_ID="0"
echo "Deal ID: $DEAL_ID"
echo ""

echo "=========================================="
echo "📋 STEP 5: Accept Deal"
echo "=========================================="

echo "Seller accepting deal $DEAL_ID"
cast send $MARKETPLACE_ADDRESS \
    "acceptDeal(uint64)" \
    $DEAL_ID \
    --private-key $SELLER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ Deal accepted"
echo ""

echo "=========================================="
echo "📋 STEP 6: Create Dispute"
echo "=========================================="

echo "Buyer creating dispute for deal $DEAL_ID"
DISPUTE_PROOF="Seller did not deliver the service as promised"

DISPUTE_TX=$(cast send $MARKETPLACE_ADDRESS \
    "createDispute(uint64,string)" \
    $DEAL_ID "$DISPUTE_PROOF" \
    --private-key $BUYER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000 \
    --json | jq -r '.transactionHash')

echo "Dispute created! TX: $DISPUTE_TX"

# Get dispute ID from Protocol (assuming it's dispute ID 0)
DISPUTE_ID="0"
echo "Dispute ID: $DISPUTE_ID"
echo ""

echo "=========================================="
echo "📋 STEP 7: Commit Votes (Judge Voting)"
echo "=========================================="

# Generate vote commits (hash of vote + secret)
# Vote true = requester (buyer) wins, false = beneficiary (seller) wins
# For testing, let's say 2 judges vote for buyer (true), 1 for seller (false)

JUDGE1_VOTE="true"
JUDGE1_SECRET="secret1"
JUDGE1_COMMIT=$(cast keccak "$(echo -n "${JUDGE1_VOTE}${JUDGE1_SECRET}")")

JUDGE2_VOTE="true"
JUDGE2_SECRET="secret2"
JUDGE2_COMMIT=$(cast keccak "$(echo -n "${JUDGE2_VOTE}${JUDGE2_SECRET}")")

JUDGE3_VOTE="false"
JUDGE3_SECRET="secret3"
JUDGE3_COMMIT=$(cast keccak "$(echo -n "${JUDGE3_VOTE}${JUDGE3_SECRET}")")

echo "Judge 1 committing vote..."
cast send $PROTOCOL_ADDRESS \
    "commitVote(uint64,bytes32)" \
    $DISPUTE_ID $JUDGE1_COMMIT \
    --private-key $JUDGE1_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 2 committing vote..."
cast send $PROTOCOL_ADDRESS \
    "commitVote(uint64,bytes32)" \
    $DISPUTE_ID $JUDGE2_COMMIT \
    --private-key $JUDGE2_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 3 committing vote..."
cast send $PROTOCOL_ADDRESS \
    "commitVote(uint64,bytes32)" \
    $DISPUTE_ID $JUDGE3_COMMIT \
    --private-key $JUDGE3_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ All votes committed"
echo ""

echo "=========================================="
echo "📋 STEP 8: Reveal Votes"
echo "=========================================="

echo "Judge 1 revealing vote..."
cast send $PROTOCOL_ADDRESS \
    "revealVotes(uint64,bool,string)" \
    $DISPUTE_ID $JUDGE1_VOTE "$JUDGE1_SECRET" \
    --private-key $JUDGE1_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 2 revealing vote..."
cast send $PROTOCOL_ADDRESS \
    "revealVotes(uint64,bool,string)" \
    $DISPUTE_ID $JUDGE2_VOTE "$JUDGE2_SECRET" \
    --private-key $JUDGE2_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 3 revealing vote..."
cast send $PROTOCOL_ADDRESS \
    "revealVotes(uint64,bool,string)" \
    $DISPUTE_ID $JUDGE3_VOTE "$JUDGE3_SECRET" \
    --private-key $JUDGE3_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ All votes revealed"
echo ""

echo "=========================================="
echo "📋 STEP 9: Check Results"
echo "=========================================="

echo "Getting dispute vote results..."
VOTE_RESULTS=$(cast call $PROTOCOL_ADDRESS \
    "get_dispute_votes(uint64)(uint8,uint8)" \
    $DISPUTE_ID \
    --rpc-url $RPC_URL)

echo "Vote Results: $VOTE_RESULTS"
echo "  Votes For Requester (Buyer):  $(echo $VOTE_RESULTS | cut -d' ' -f1)"
echo "  Votes For Beneficiary (Seller): $(echo $VOTE_RESULTS | cut -d' ' -f2)"
echo ""

echo "Getting dispute winner..."
WINNER=$(cast call $PROTOCOL_ADDRESS \
    "getDisputeWinner(uint64)(bool)" \
    $DISPUTE_ID \
    --rpc-url $RPC_URL)

if [ "$WINNER" == "true" ]; then
    echo "🏆 Winner: Buyer (Requester)"
else
    echo "🏆 Winner: Seller (Beneficiary)"
fi
echo ""

echo "=========================================="
echo "📋 STEP 10: Execute Dispute Result"
echo "=========================================="

echo "Executing dispute result in marketplace..."
cast send $MARKETPLACE_ADDRESS \
    "executeDisputeResult(uint64)" \
    $DISPUTE_ID \
    --private-key $BUYER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ Dispute result executed"
echo ""

echo "=========================================="
echo "✅ ALL TESTS COMPLETED SUCCESSFULLY!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - 3 Judges registered in Protocol"
echo "  - 2 Users registered in Marketplace (Buyer & Seller)"
echo "  - Deal created and accepted"
echo "  - Dispute created and voted on"
echo "  - Result: $([ "$WINNER" == "true" ] && echo "Buyer wins" || echo "Seller wins")"
echo ""
echo "Check deployment.log for full transaction details"
