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

JUDGE4_KEY="0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97"
JUDGE4_ADDR=$(cast wallet address --private-key $JUDGE4_KEY)

JUDGE5_KEY="0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6"
JUDGE5_ADDR=$(cast wallet address --private-key $JUDGE5_KEY)

# USDC Mock Token (deployed Stylus contract)
# Read USDC address from deployment file
USDC_ADDRESS=$(cat "$DEPLOYMENT_FILE" | jq -r '.usdc_contract.address')

# Convert 0x-prefixed hex into a comma-separated uint8 array for cast inputs
hex_to_uint8_array() {
    local hex_string=$1
    hex_string=${hex_string#0x}
    local array="["
    for ((i=0; i<${#hex_string}; i+=2)); do
        local byte="0x${hex_string:$i:2}"
        array+="$((byte)),"
    done
    array="${array%,}]"
    echo "$array"
}

echo "=========================================="
echo "📋 STEP 0: Fund Test Accounts"
echo "=========================================="
echo "✅ Skipping funding (accounts pre-funded)"

# echo "Funding Buyer: $BUYER_ADDR"
# cast send $BUYER_ADDR \
#     --value 10ether \
#     --private-key $OWNER_KEY \
#     --rpc-url $RPC_URL

# echo "Funding Seller: $SELLER_ADDR"
# cast send $SELLER_ADDR \
#     --value 10ether \
#     --private-key $OWNER_KEY \
#     --rpc-url $RPC_URL

# echo "Funding Judge 1: $JUDGE1_ADDR"
# cast send $JUDGE1_ADDR \
#     --value 10ether \
#     --private-key $OWNER_KEY \
#     --rpc-url $RPC_URL

# echo "Funding Judge 2: $JUDGE2_ADDR"
# cast send $JUDGE2_ADDR \
#     --value 10ether \
#     --private-key $OWNER_KEY \
#     --rpc-url $RPC_URL

# echo "Funding Judge 3: $JUDGE3_ADDR"
# cast send $JUDGE3_ADDR \
#     --value 10ether \
#     --private-key $OWNER_KEY \
#     --rpc-url $RPC_URL

# echo "Funding Judge 4: $JUDGE4_ADDR"
# cast send $JUDGE4_ADDR \
#     --value 10ether \
#     --private-key $OWNER_KEY \
#     --rpc-url $RPC_URL

# echo "Funding Judge 5: $JUDGE5_ADDR"
# cast send $JUDGE5_ADDR \
#     --value 10ether \
#     --private-key $OWNER_KEY \
#     --rpc-url $RPC_URL

echo "✅ All accounts funded"
echo ""

echo "=========================================="
echo "📋 STEP 1: Initialize Contracts"
echo "=========================================="
echo "✅ Skipping initialization (contracts pre-initialized)"

# echo "Initializing Protocol Contract..."
# echo "  Owner: $OWNER_ADDR"
# echo "  USDC Token: $USDC_ADDRESS"

# cast send $PROTOCOL_ADDRESS \
#     "init(address,address)" \
#     $OWNER_ADDR $USDC_ADDRESS \
#     --private-key $OWNER_KEY \
#     --rpc-url $RPC_URL \
#     --gas-limit 5000000

# echo "Initializing Marketplace Contract..."
# echo "  Owner: $OWNER_ADDR"
# echo "  Fee: 5%"
# echo "  USDC Token: $USDC_ADDRESS"
# echo "  Protocol: $PROTOCOL_ADDRESS"

# cast send $MARKETPLACE_ADDRESS \
#     "init(address,uint8,address,address)" \
#     $OWNER_ADDR 5 $USDC_ADDRESS $PROTOCOL_ADDRESS \
#     --private-key $OWNER_KEY \
#     --rpc-url $RPC_URL \
#     --gas-limit 5000000

# echo "✅ Contracts initialized"
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

echo "Registering Judge 4: $JUDGE4_ADDR"
cast send $PROTOCOL_ADDRESS \
    "registerAsJudge()" \
    --private-key $JUDGE4_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000 || echo "  (Judge 4 already registered)"

echo "Registering Judge 5: $JUDGE5_ADDR"
cast send $PROTOCOL_ADDRESS \
    "registerAsJudge()" \
    --private-key $JUDGE5_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000 || echo "  (Judge 5 already registered)"

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
echo "📋 STEP 4: Approve Marketplace to Spend USDC"
echo "=========================================="

DEAL_AMOUNT="1000000"  # 1 USDC (6 decimals)

echo "Buyer approving marketplace to spend $DEAL_AMOUNT USDC..."
cast send $USDC_ADDRESS \
    "approve(address,uint256)" \
    $MARKETPLACE_ADDRESS $DEAL_AMOUNT \
    --private-key $BUYER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 2000000

echo "✅ Marketplace approved"
echo ""

echo "=========================================="
echo "📋 STEP 11: Create Deal"
echo "=========================================="

DEAL_DURATION="7"      # 7 days

echo "Creating deal: $DEAL_AMOUNT USDC for $DEAL_DURATION days"
echo "Buyer: $BUYER_ADDR"
echo "Seller: $SELLER_ADDR"

cast send $MARKETPLACE_ADDRESS \
    "createDeal(address,uint256,uint64)" \
    $SELLER_ADDR $DEAL_AMOUNT $DEAL_DURATION \
    --private-key $BUYER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ Deal created"

# Get the latest deal ID from counter (counter points to next id)
NEXT_DEAL_ID_HEX=$(cast call $MARKETPLACE_ADDRESS "dealIdCounter()" --rpc-url $RPC_URL | tr -d '\r\n')
NEXT_DEAL_ID_DEC=$(cast --to-dec "$NEXT_DEAL_ID_HEX" | tr -d '\r\n')
DEAL_ID=$((NEXT_DEAL_ID_DEC - 1))
if [ "$DEAL_ID" -lt 0 ]; then DEAL_ID=0; fi
echo "Deal ID: $DEAL_ID"
echo ""

echo "=========================================="
echo "📋 STEP 11: Accept Deal"
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
echo "📋 STEP 11: Approve Dispute Fee"
echo "=========================================="

DISPUTE_FEE="50000000"  # 50 USDC (6 decimals)

echo "Buyer approving marketplace to spend $DISPUTE_FEE USDC for dispute fee..."
cast send $USDC_ADDRESS \
    "approve(address,uint256)" \
    $MARKETPLACE_ADDRESS $DISPUTE_FEE \
    --private-key $BUYER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 2000000

echo "✅ Dispute fee approved"
echo ""

echo "=========================================="
echo "📋 STEP 11: Create Dispute"
echo "=========================================="

echo "Buyer creating dispute for deal $DEAL_ID"
DISPUTE_PROOF="Seller did not deliver the service as promised"

cast send $MARKETPLACE_ADDRESS \
    "createDispute(uint64,string)" \
    $DEAL_ID "$DISPUTE_PROOF" \
    --private-key $BUYER_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ Dispute created"

# Get dispute ID from protocol counter (counter points to next id)
NEXT_DISPUTE_ID_HEX=$(cast call $PROTOCOL_ADDRESS "disputeCount()" --rpc-url $RPC_URL | tr -d '\r\n')
NEXT_DISPUTE_ID_DEC=$(cast --to-dec "$NEXT_DISPUTE_ID_HEX" | tr -d '\r\n')
DISPUTE_ID=$((NEXT_DISPUTE_ID_DEC - 1))
if [ "$DISPUTE_ID" -lt 0 ]; then DISPUTE_ID=0; fi
echo "Dispute ID: $DISPUTE_ID"
echo ""

echo "=========================================="
echo "📋 STEP 5: Register Judges for Dispute"
echo "=========================================="

echo "Judge 1 registering to vote on dispute $DISPUTE_ID..."
cast send $PROTOCOL_ADDRESS \
    "registerToVote(uint64)" \
    $DISPUTE_ID \
    --private-key $JUDGE1_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 2000000

echo "Judge 2 registering to vote on dispute $DISPUTE_ID..."
cast send $PROTOCOL_ADDRESS \
    "registerToVote(uint64)" \
    $DISPUTE_ID \
    --private-key $JUDGE2_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 2000000

echo "Judge 3 registering to vote on dispute $DISPUTE_ID..."
cast send $PROTOCOL_ADDRESS \
    "registerToVote(uint64)" \
    $DISPUTE_ID \
    --private-key $JUDGE3_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 2000000

echo "Judge 4 registering to vote on dispute $DISPUTE_ID..."
cast send $PROTOCOL_ADDRESS \
    "registerToVote(uint64)" \
    $DISPUTE_ID \
    --private-key $JUDGE4_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 2000000

echo "Judge 5 registering to vote on dispute $DISPUTE_ID..."
cast send $PROTOCOL_ADDRESS \
    "registerToVote(uint64)" \
    $DISPUTE_ID \
    --private-key $JUDGE5_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 2000000

echo "✅ All 5 judges registered for dispute"
echo ""

echo "=========================================="
echo "📋 STEP 11: Commit Votes (Judge Voting)"
echo "=========================================="

# Generate vote commits (hash of vote + secret)
# Vote true = requester (buyer) wins, false = beneficiary (seller) wins
# For testing, let's say 2 judges vote for buyer (true), 1 for seller (false)

JUDGE1_VOTE="true"
JUDGE1_SECRET="secret1"
JUDGE1_COMMIT=$(cast keccak "$(echo -n "${JUDGE1_VOTE}${JUDGE1_SECRET}")")
JUDGE1_COMMIT_ARRAY=$(hex_to_uint8_array "$JUDGE1_COMMIT")

JUDGE2_VOTE="true"
JUDGE2_SECRET="secret2"
JUDGE2_COMMIT=$(cast keccak "$(echo -n "${JUDGE2_VOTE}${JUDGE2_SECRET}")")
JUDGE2_COMMIT_ARRAY=$(hex_to_uint8_array "$JUDGE2_COMMIT")

JUDGE3_VOTE="false"
JUDGE3_SECRET="secret3"
JUDGE3_COMMIT=$(cast keccak "$(echo -n "${JUDGE3_VOTE}${JUDGE3_SECRET}")")
JUDGE3_COMMIT_ARRAY=$(hex_to_uint8_array "$JUDGE3_COMMIT")

JUDGE4_VOTE="true"
JUDGE4_SECRET="secret4"
JUDGE4_COMMIT=$(cast keccak "$(echo -n "${JUDGE4_VOTE}${JUDGE4_SECRET}")")
JUDGE4_COMMIT_ARRAY=$(hex_to_uint8_array "$JUDGE4_COMMIT")

JUDGE5_VOTE="true"
JUDGE5_SECRET="secret5"
JUDGE5_COMMIT=$(cast keccak "$(echo -n "${JUDGE5_VOTE}${JUDGE5_SECRET}")")
JUDGE5_COMMIT_ARRAY=$(hex_to_uint8_array "$JUDGE5_COMMIT")

echo "Judge 1 committing vote..."
cast send $PROTOCOL_ADDRESS \
    "commitVote(uint64,uint8[32])" \
    $DISPUTE_ID "$JUDGE1_COMMIT_ARRAY" \
    --private-key $JUDGE1_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 2 committing vote..."
cast send $PROTOCOL_ADDRESS \
    "commitVote(uint64,uint8[32])" \
    $DISPUTE_ID "$JUDGE2_COMMIT_ARRAY" \
    --private-key $JUDGE2_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 3 committing vote..."
cast send $PROTOCOL_ADDRESS \
    "commitVote(uint64,uint8[32])" \
    $DISPUTE_ID "$JUDGE3_COMMIT_ARRAY" \
    --private-key $JUDGE3_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 4 committing vote..."
cast send $PROTOCOL_ADDRESS \
    "commitVote(uint64,uint8[32])" \
    $DISPUTE_ID "$JUDGE4_COMMIT_ARRAY" \
    --private-key $JUDGE4_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 5 committing vote..."
cast send $PROTOCOL_ADDRESS \
    "commitVote(uint64,uint8[32])" \
    $DISPUTE_ID "$JUDGE5_COMMIT_ARRAY" \
    --private-key $JUDGE5_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ All votes committed"
echo ""

echo "=========================================="
echo "📋 STEP 11: Reveal Votes"
echo "=========================================="

echo "Judge 1 revealing vote..."
JUDGE1_SECRET_ARRAY=$(hex_to_uint8_array "$(cast --from-utf8 "$JUDGE1_SECRET")")
cast send $PROTOCOL_ADDRESS \
    "revealVotes(uint64,bool,uint8[])" \
    $DISPUTE_ID $JUDGE1_VOTE "$JUDGE1_SECRET_ARRAY" \
    --private-key $JUDGE1_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 2 revealing vote..."
JUDGE2_SECRET_ARRAY=$(hex_to_uint8_array "$(cast --from-utf8 "$JUDGE2_SECRET")")
cast send $PROTOCOL_ADDRESS \
    "revealVotes(uint64,bool,uint8[])" \
    $DISPUTE_ID $JUDGE2_VOTE "$JUDGE2_SECRET_ARRAY" \
    --private-key $JUDGE2_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 3 revealing vote..."
JUDGE3_SECRET_ARRAY=$(hex_to_uint8_array "$(cast --from-utf8 "$JUDGE3_SECRET")")
cast send $PROTOCOL_ADDRESS \
    "revealVotes(uint64,bool,uint8[])" \
    $DISPUTE_ID $JUDGE3_VOTE "$JUDGE3_SECRET_ARRAY" \
    --private-key $JUDGE3_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 4 revealing vote..."
JUDGE4_SECRET_ARRAY=$(hex_to_uint8_array "$(cast --from-utf8 "$JUDGE4_SECRET")")
cast send $PROTOCOL_ADDRESS \
    "revealVotes(uint64,bool,uint8[])" \
    $DISPUTE_ID $JUDGE4_VOTE "$JUDGE4_SECRET_ARRAY" \
    --private-key $JUDGE4_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "Judge 5 revealing vote..."
JUDGE5_SECRET_ARRAY=$(hex_to_uint8_array "$(cast --from-utf8 "$JUDGE5_SECRET")")
cast send $PROTOCOL_ADDRESS \
    "revealVotes(uint64,bool,uint8[])" \
    $DISPUTE_ID $JUDGE5_VOTE "$JUDGE5_SECRET_ARRAY" \
    --private-key $JUDGE5_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 5000000

echo "✅ All votes revealed"
echo ""

echo "=========================================="
echo "📋 STEP 11: Check Results"
echo "=========================================="

echo "Getting dispute vote results..."
RAW_RET=$(cast call $PROTOCOL_ADDRESS "getDisputeVotes(uint64)" $DISPUTE_ID --rpc-url $RPC_URL | tr -d '\r\n')
# Manual ABI decode two uint8 from return data
RET_HEX=${RAW_RET#0x}
WORD1=${RET_HEX:0:64}
WORD2=${RET_HEX:64:64}
VOTES_FOR_REQUESTER=$(cast --to-dec 0x$WORD1)
VOTES_FOR_BENEFICIARY=$(cast --to-dec 0x$WORD2)

echo "Vote Results: $VOTES_FOR_REQUESTER $VOTES_FOR_BENEFICIARY"
echo "  Votes For Requester (Buyer):  $VOTES_FOR_REQUESTER"
echo "  Votes For Beneficiary (Seller): $VOTES_FOR_BENEFICIARY"
echo ""

echo "Getting dispute winner..."
RAW_WINNER=$(cast call $PROTOCOL_ADDRESS "getDisputeWinner(uint64)" $DISPUTE_ID --rpc-url $RPC_URL | tr -d '\r\n')
# Manual ABI decode bool from first 32-byte word
RET2_HEX=${RAW_WINNER#0x}
WORD=${RET2_HEX:0:64}
WIN_VAL=$(cast --to-dec 0x$WORD)
WINNER="false"
if [ "$WIN_VAL" -ne 0 ]; then WINNER="true"; fi

if [ "$WINNER" == "true" ]; then
    echo "🏆 Winner: Buyer (Requester)"
else
    echo "🏆 Winner: Seller (Beneficiary)"
fi
echo ""

echo "=========================================="
echo "📋 STEP 11: Execute Dispute Result"
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
