# Dockerfile for Hardhat Blockchain Service
FROM node:22-alpine

WORKDIR /app

# Install git for any git-based dependencies
RUN apk add --no-cache git

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production || npm install --only=production

# Copy source code
COPY . .

# Compile contracts
RUN npx hardhat compile

# Create non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose Hardhat node port
EXPOSE 8545

# Default command - start Hardhat node
CMD ["npx", "hardhat", "node", "--hostname", "0.0.0.0"]

