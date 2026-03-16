#!/bin/bash

# Define constants 
AMOUNT=100000

DEFAULT_ZKSYNC_LOCAL_KEY="0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110"
DEFAULT_ZKSYNC_ADDRESS="0x36615Cf349d7F6344891B1e7CA7C72883F5dc049"

ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM="0x57Fe4Ed8DF1c044f7E6860415A8aa61eE7597657"
ZKSYNC_TOKEN_ADMIN_REGISTRY="0xc7777f12258014866c677Bdb679D0b007405b7DF"
ZKSYNC_ROUTER="0xA1fdA8aa9A8C4b945C45aD30647b01f07D7A0B16"
ZKSYNC_RNM_PROXY_ADDRESS="0x3DA20FD3D8a8f8c1f1A5fD03648147143608C467"
ZKSYNC_SEPOLIA_CHAIN_SELECTOR="6898391096552792247"
ZKSYNC_LINK_ADDRESS="0x23A1aFD896c8c8876AF46aDc38521f4432658d1e"

SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0xa3c796d480638d7476792230da1E2ADa86e031b0"
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82"
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"

# Compile and deploy the Rebase Token contract
source .env
forge build --zksync
echo "Compiling and deploying the Rebase Token contract on ZKsync..."
ZKSYNC_REBASE_TOKEN_ADDRESS=$(forge create src/RebaseToken.sol:RebaseToken --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount --legacy --zksync --broadcast| awk '/Deployed to:/ {print $3}')
echo "ZKsync rebase token address: $ZKSYNC_REBASE_TOKEN_ADDRESS"

# Compile and deploy the pool contract
echo "Compiling and deploying the pool contract on ZKsync..."
ZKSYNC_POOL_ADDRESS=$(forge create src/RebaseTokenPool.sol:RebaseTokenPool --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount --legacy --zksync --broadcast --constructor-args ${ZKSYNC_REBASE_TOKEN_ADDRESS} [] ${ZKSYNC_RNM_PROXY_ADDRESS} ${ZKSYNC_ROUTER} | awk '/Deployed to:/ {print $3}')
echo "Pool address: $ZKSYNC_POOL_ADDRESS"

# Set the permissions for the pool contract
echo "Setting the permissions for the pool contract on ZKsync..."
cast send ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount "grantMintAndBurnRole(address)" ${ZKSYNC_POOL_ADDRESS}
echo "Pool permissions set"

# Set the CCIP roles and permissions
echo "Setting the CCIP roles and permissions on ZKsync..."
cast send ${ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM} "registerAdminViaOwner(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "acceptAdminRole(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "setPool(address,address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} ${ZKSYNC_POOL_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
echo "CCIP roles and permissions set"

# 2. On Sepolia!

echo "Running the script to deploy the contracts on Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast 2>&1)
echo "$output"
echo "Contracts deployed and permission set on Sepolia"

# Extract the addresses from the output
SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'tokenPool: contract RebaseTokenPool' | awk '{print $4}')

echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

# Deploy the vault 
echo "Deploying the vault on Sepolia..."
VAULT_ADDRESS=$(forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} | grep 'vault: contract Vault' | awk '{print $NF}')
echo "Vault address: $VAULT_ADDRESS"

#Setting admin role and granting role
echo "I hope this is how you set admin and role..."
forge script ./script/Deployer.s.sol:SetPermission --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --sig "grantRole(address,address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${SEPOLIA_POOL_ADDRESS}
forge script ./script/Deployer.s.sol:SetPermission --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --sig "setAdmin(address,address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${SEPOLIA_POOL_ADDRESS}


# Configure the pool on Sepolia
echo "Configuring the pool on Sepolia..."
# uint64 remoteChainSelector,
#         address remotePoolAddress, /
#         address remoteTokenAddress, /
#         bool outboundRateLimiterIsEnabled, false 
#         uint128 outboundRateLimiterCapacity, 0
#         uint128 outboundRateLimiterRate, 0
#         bool inboundRateLimiterIsEnabled, false 
#         uint128 inboundRateLimiterCapacity, 0 
#         uint128 inboundRateLimiterRate 0 
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${ZKSYNC_POOL_ADDRESS} ${ZKSYNC_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Deposit funds to the vault
echo "Depositing funds to the vault on Sepolia..."
cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account myaccount "deposit()"

# Wait a beat for some interest to accrue

# Configure the pool on ZKsync
echo "Configuring the pool on ZKsync..."
ENCODED_SEPOLIA_POOL=$(cast abi-encode "f(address)" ${SEPOLIA_POOL_ADDRESS})
ENCODED_SEPOLIA_TOKEN=$(cast abi-encode "f(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS})

cast send ${ZKSYNC_POOL_ADDRESS} \
  --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
  --account myaccount \
  "applyChainUpdates(uint64[],(uint64,bytes[],bytes,(bool,uint128,uint128),(bool,uint128,uint128))[])" \
  "[]" \
  "[(${SEPOLIA_CHAIN_SELECTOR},[${ENCODED_SEPOLIA_POOL}],${ENCODED_SEPOLIA_TOKEN},(false,0,0),(false,0,0))]"
  
# Bridge the funds using the script to zksync 
 echo "Bridging the funds using the script to ZKsync..."
 SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account myaccount) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"
forge script ./script/BridgeToken.s.sol:BridgeScript --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --sig "run(uint64,address,address,address,uint256,address)" ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} $(cast wallet address --account myaccount) ${SEPOLIA_ROUTER} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS}
echo "Funds bridged to ZKsync"
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account myaccount) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"