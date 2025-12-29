# BookingPaymentContract Deployment

## Deployment Information

**Date:** 2025-12-29T19:37:24.685Z
**Network:** localhost
**Chain ID:** 31337

## Contract Address

```
0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0
```

## Configuration

- **Platform Wallet:** 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
- **Platform Fee:** 10%
- **Admin:** 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
- **Deployer:** 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

## Application Properties Configuration

Add/Update these values in `payment-service/src/main/resources/application.properties`:

```properties
# Blockchain Configuration
app.web3.chain-id=31337
app.web3.rpc-url=http://127.0.0.1:8545
app.web3.contract-address=0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0
app.web3.private-key=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**⚠️ IMPORTANT:** The private key above is for Hardhat local network ONLY. 
**NEVER use this in production!**

## Contract Functions

### Public Functions

- `createBookingPayment(uint256,address,address,uint256,uint256) - payable`
- `completeBooking(uint256) - only host or admin`
- `cancelBooking(uint256) - only guest or admin`
- `getBooking(uint256) - view`
- `bookingExistsCheck(uint256) - view`
- `getContractBalance() - view`
- `getBookingWithReclamation(uint256) - view`
- `getReclamationRefund(uint256) - view`

### Admin Functions

- `transferAdmin(address) - only admin`
- `emergencyWithdraw() - only admin`
- `processReclamationRefund(uint256,address,uint256,uint256,bool) - only admin`
- `processPartialRefund(uint256,address,uint256,bool) - only admin`
- `setActiveReclamation(uint256,bool) - only admin`

### Constants

- `PLATFORM_WALLET() - constant`
- `PLATFORM_FEE_PERCENT() - constant`
- `admin() - public`

## Testing

To test the contract, use Hardhat console:

```bash
npx hardhat console --network localhost
```

Then:

```javascript
const contract = await ethers.getContractAt("BookingPaymentContract", "0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0");
await contract.PLATFORM_WALLET();
await contract.admin();
await contract.getContractBalance();
```

## Next Steps

1. Update `application.properties` with the contract address above
2. Restart payment-service
3. Test the contract using the API endpoints
