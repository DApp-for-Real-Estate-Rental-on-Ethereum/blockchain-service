const { ethers } = require("hardhat");

async function main() {
  console.log("Hardhat Accounts Private Keys:\n");
  console.log("=" .repeat(60));
  
  // Hardhat uses a default mnemonic, we'll derive accounts from it
  const mnemonic = "test test test test test test test test test test test junk";
  const hdNode = ethers.HDNodeWallet.fromPhrase(mnemonic);
  
  // Generate 10 accounts (Hardhat default)
  for (let i = 0; i < 10; i++) {
    const wallet = hdNode.derivePath(`m/44'/60'/0'/0/${i}`);
    const address = wallet.address;
    const privateKey = wallet.privateKey;
    const balance = await ethers.provider.getBalance(address);
    const balanceInEth = ethers.formatEther(balance);
    
    console.log(`\nAccount #${i}:`);
    console.log(`  Address: ${address}`);
    console.log(`  Private Key: ${privateKey}`);
    console.log(`  Balance: ${balanceInEth} ETH`);
    console.log("-".repeat(60));
  }
  
  console.log("\n✅ All accounts listed above!");
  console.log("\nTo import into MetaMask:");
  console.log("1. Open MetaMask");
  console.log("2. Click on account icon → Import Account");
  console.log("3. Paste the Private Key");
  console.log("4. Click Import");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


