#!/bin/bash

# Script to start Hardhat local node
# Usage: ./start-node.sh

echo "=========================================="
echo "Starting Hardhat Local Node"
echo "=========================================="
echo ""
echo "This will start a local Ethereum node on http://127.0.0.1:8545"
echo "Press Ctrl+C to stop the node"
echo ""
echo "=========================================="
echo ""

# Start Hardhat node
npx hardhat node

