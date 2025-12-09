const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * Complete deployment script for BookingPaymentContract
 * This script:
 * 1. Compiles the contract
 * 2. Deploys to the specified network
 * 3. Verifies deployment
 * 4. Saves all deployment info including addresses and keys
 * 5. Updates application.properties automatically
 */

async function main() {
  console.log("=".repeat(80));
  console.log("🚀 DEPLOYING BOOKING PAYMENT CONTRACT");
  console.log("=".repeat(80));

  const network = hre.network.name;
  const chainId = (await hre.ethers.provider.getNetwork()).chainId;
  
  console.log(`\n📡 Network: ${network}`);
  console.log(`🔗 Chain ID: ${chainId.toString()}`);

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  const deployerBalance = await hre.ethers.provider.getBalance(deployerAddress);
  
  console.log(`\n👤 Deployer Account:`);
  console.log(`   Address: ${deployerAddress}`);
  console.log(`   Balance: ${hre.ethers.formatEther(deployerBalance)} ETH`);

  // Deploy contract
  console.log(`\n📦 Deploying BookingPaymentContract...`);
  const BookingPaymentContract = await hre.ethers.getContractFactory("BookingPaymentContract");
  const bookingPayment = await BookingPaymentContract.deploy();
  
  await bookingPayment.waitForDeployment();
  const contractAddress = await bookingPayment.getAddress();
  
  console.log(`\n✅ Contract deployed successfully!`);
  console.log(`   Address: ${contractAddress}`);

  // Verify contract deployment
  console.log(`\n🔍 Verifying contract deployment...`);
  const code = await hre.ethers.provider.getCode(contractAddress);
  if (code === "0x") {
    throw new Error("❌ Contract deployment failed - no code at address!");
  }
  console.log(`   ✅ Contract code verified (${code.length / 2 - 1} bytes)`);

  // Get contract configuration
  console.log(`\n📋 Reading contract configuration...`);
  const platformWallet = await bookingPayment.PLATFORM_WALLET();
  const platformFee = await bookingPayment.PLATFORM_FEE_PERCENT();
  const admin = await bookingPayment.admin();
  
  console.log(`\n📊 Contract Configuration:`);
  console.log(`   Platform Wallet: ${platformWallet}`);
  console.log(`   Platform Fee: ${platformFee.toString()}%`);
  console.log(`   Admin: ${admin}`);

  // Verify admin matches deployer
  if (admin.toLowerCase() !== deployerAddress.toLowerCase()) {
    console.warn(`   ⚠️  WARNING: Admin (${admin}) does not match deployer (${deployerAddress})`);
  } else {
    console.log(`   ✅ Admin matches deployer`);
  }

  // Get Hardhat accounts info (for localhost/hardhat networks)
  let accountsInfo = [];
  if (network === "localhost" || network === "hardhat") {
    const accounts = await hre.ethers.getSigners();
    for (let i = 0; i < Math.min(5, accounts.length); i++) {
      const account = accounts[i];
      const address = await account.getAddress();
      const balance = await hre.ethers.provider.getBalance(address);
      
      // For account #0, this is the admin - save private key info
      if (i === 0) {
        accountsInfo.push({
          index: i,
          address: address,
          balance: hre.ethers.formatEther(balance),
          isAdmin: true,
          note: "This is the admin account - use this private key in application.properties"
        });
      } else {
        accountsInfo.push({
          index: i,
          address: address,
          balance: hre.ethers.formatEther(balance),
          isAdmin: false
        });
      }
    }
  }

  // Prepare deployment info
  const deploymentInfo = {
    contract: {
      name: "BookingPaymentContract",
      address: contractAddress,
      network: network,
      chainId: chainId.toString(),
      deployer: deployerAddress,
      timestamp: new Date().toISOString(),
      blockNumber: await hre.ethers.provider.getBlockNumber()
    },
    configuration: {
      platformWallet: platformWallet,
      platformFeePercent: platformFee.toString(),
      admin: admin
    },
    accounts: accountsInfo,
    functions: {
      public: [
        "createBookingPayment(uint256,address,address,uint256,uint256) - payable",
        "completeBooking(uint256) - only host or admin",
        "cancelBooking(uint256) - only guest or admin",
        "getBooking(uint256) - view",
        "bookingExistsCheck(uint256) - view",
        "getContractBalance() - view",
        "getBookingWithReclamation(uint256) - view",
        "getReclamationRefund(uint256) - view"
      ],
      admin: [
        "transferAdmin(address) - only admin",
        "emergencyWithdraw() - only admin",
        "processReclamationRefund(uint256,address,uint256,uint256,bool) - only admin",
        "processPartialRefund(uint256,address,uint256,bool) - only admin",
        "setActiveReclamation(uint256,bool) - only admin"
      ],
      constants: [
        "PLATFORM_WALLET() - constant",
        "PLATFORM_FEE_PERCENT() - constant",
        "admin() - public"
      ]
    }
  };

  // Save deployment info
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentFile = path.join(deploymentsDir, `booking-payment-${network}.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\n💾 Deployment info saved to: ${deploymentFile}`);

  // Create comprehensive documentation
  const docFile = path.join(deploymentsDir, `DEPLOYMENT-${network}-${Date.now()}.md`);
  const documentation = `# BookingPaymentContract Deployment

## Deployment Information

**Date:** ${new Date().toISOString()}
**Network:** ${network}
**Chain ID:** ${chainId.toString()}

## Contract Address

\`\`\`
${contractAddress}
\`\`\`

## Configuration

- **Platform Wallet:** ${platformWallet}
- **Platform Fee:** ${platformFee.toString()}%
- **Admin:** ${admin}
- **Deployer:** ${deployerAddress}

## Application Properties Configuration

Add/Update these values in \`payment-service/src/main/resources/application.properties\`:

\`\`\`properties
# Blockchain Configuration
app.web3.chain-id=${chainId}
app.web3.rpc-url=${network === "localhost" ? "http://127.0.0.1:8545" : "https://arb1.arbitrum.io/rpc"}
app.web3.contract-address=${contractAddress}
app.web3.private-key=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
\`\`\`

**⚠️ IMPORTANT:** The private key above is for Hardhat local network ONLY. 
**NEVER use this in production!**

## Contract Functions

### Public Functions

${deploymentInfo.functions.public.map(f => `- \`${f}\``).join("\n")}

### Admin Functions

${deploymentInfo.functions.admin.map(f => `- \`${f}\``).join("\n")}

### Constants

${deploymentInfo.functions.constants.map(f => `- \`${f}\``).join("\n")}

## Testing

To test the contract, use Hardhat console:

\`\`\`bash
npx hardhat console --network ${network}
\`\`\`

Then:

\`\`\`javascript
const contract = await ethers.getContractAt("BookingPaymentContract", "${contractAddress}");
await contract.PLATFORM_WALLET();
await contract.admin();
await contract.getContractBalance();
\`\`\`

## Next Steps

1. Update \`application.properties\` with the contract address above
2. Restart payment-service
3. Test the contract using the API endpoints
`;

  fs.writeFileSync(docFile, documentation);
  console.log(`📄 Documentation saved to: ${docFile}`);

  // Try to update application.properties automatically
  const appPropertiesPath = path.join(__dirname, "..", "..", "payment-service", "src", "main", "resources", "application.properties");
  if (fs.existsSync(appPropertiesPath)) {
    console.log(`\n🔄 Attempting to update application.properties...`);
    try {
      let properties = fs.readFileSync(appPropertiesPath, "utf8");
      
      // Update contract address
      properties = properties.replace(
        /app\.web3\.contract-address=.*/,
        `app.web3.contract-address=${contractAddress}`
      );
      
      // Update chain ID
      properties = properties.replace(
        /app\.web3\.chain-id=.*/,
        `app.web3.chain-id=${chainId}`
      );
      
      // Update RPC URL if needed
      if (network === "localhost") {
        properties = properties.replace(
          /app\.web3\.rpc-url=.*/,
          `app.web3.rpc-url=http://127.0.0.1:8545`
        );
      }
      
      fs.writeFileSync(appPropertiesPath, properties);
      console.log(`   ✅ application.properties updated successfully!`);
    } catch (error) {
      console.warn(`   ⚠️  Could not update application.properties: ${error.message}`);
      console.log(`   Please update manually with the contract address above`);
    }
  } else {
    console.log(`\n⚠️  application.properties not found at: ${appPropertiesPath}`);
    console.log(`   Please update manually with the contract address above`);
  }

  // Summary
  console.log("\n" + "=".repeat(80));
  console.log("✅ DEPLOYMENT COMPLETE!");
  console.log("=".repeat(80));
  console.log(`\n📝 Summary:`);
  console.log(`   Contract Address: ${contractAddress}`);
  console.log(`   Network: ${network} (Chain ID: ${chainId})`);
  console.log(`   Admin: ${admin}`);
  console.log(`\n📋 Next Steps:`);
  console.log(`   1. Update application.properties with the contract address`);
  console.log(`   2. Restart payment-service`);
  console.log(`   3. Test the deployment`);
  console.log("\n" + "=".repeat(80));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n" + "=".repeat(80));
    console.error("❌ DEPLOYMENT FAILED!");
    console.error("=".repeat(80));
    console.error(error);
    process.exit(1);
  });

