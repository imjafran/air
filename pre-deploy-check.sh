#!/bin/bash

# Pre-deployment Check for AWS Lightsail
# Run this BEFORE deploying to verify everything is ready

set +e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  Air - Pre-Deployment Check"
echo "========================================="
echo ""

# Configuration
DOMAIN="air.arraystory.com"
SERVER_IP=""

# Check if SERVER_IP is provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Please provide your Lightsail server IP address:${NC}"
    read -p "IP Address: " SERVER_IP
else
    SERVER_IP=$1
fi

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Error: Server IP required${NC}"
    exit 1
fi

echo "Domain: $DOMAIN"
echo "Server IP: $SERVER_IP"
echo ""

PASSED=0
FAILED=0

# Check 1: DNS Resolution
echo -n "✓ Checking DNS for $DOMAIN... "
DNS_IP=$(dig +short $DOMAIN A | tail -n1)
if [ -z "$DNS_IP" ]; then
    echo -e "${RED}FAILED${NC}"
    echo "  Domain does not resolve to any IP"
    echo "  Action: Add A record in your DNS settings pointing to $SERVER_IP"
    FAILED=$((FAILED + 1))
elif [ "$DNS_IP" != "$SERVER_IP" ]; then
    echo -e "${YELLOW}WARNING${NC}"
    echo "  Domain resolves to: $DNS_IP"
    echo "  Expected: $SERVER_IP"
    echo "  Action: Update A record to point to $SERVER_IP"
    echo "  Note: DNS changes can take up to 48 hours to propagate"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}PASSED${NC}"
    echo "  Domain correctly points to $SERVER_IP"
    PASSED=$((PASSED + 1))
fi
echo ""

# Check 2: SSH Connection
echo -n "✓ Testing SSH connection... "
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "exit" 2>/dev/null; then
    echo -e "${GREEN}PASSED${NC}"
    echo "  SSH connection successful"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}FAILED${NC}"
    echo "  Cannot connect via SSH"
    echo "  Action: Check your SSH key and security group settings"
    echo "  Try: ssh ubuntu@$SERVER_IP"
    FAILED=$((FAILED + 1))
fi
echo ""

# Check 3: Server Resources (if SSH works)
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "exit" 2>/dev/null; then
    echo "✓ Checking server resources..."

    # Check RAM
    TOTAL_RAM=$(ssh ubuntu@$SERVER_IP "free -m | awk '/^Mem:/{print \$2}'" 2>/dev/null)
    echo -n "  RAM: ${TOTAL_RAM}MB "
    if [ "$TOTAL_RAM" -lt 1024 ]; then
        echo -e "${YELLOW}WARNING${NC}"
        echo "    Recommended: 1GB+ (You have less than 1GB)"
    elif [ "$TOTAL_RAM" -lt 2048 ]; then
        echo -e "${YELLOW}OK${NC}"
        echo "    Acceptable for production"
        PASSED=$((PASSED + 1))
    else
        echo -e "${GREEN}EXCELLENT${NC}"
        echo "    Great for production"
        PASSED=$((PASSED + 1))
    fi

    # Check Disk
    FREE_DISK=$(ssh ubuntu@$SERVER_IP "df -BG / | tail -1 | awk '{print \$4}' | sed 's/G//'" 2>/dev/null)
    echo -n "  Disk: ${FREE_DISK}GB free "
    if [ "$FREE_DISK" -lt 5 ]; then
        echo -e "${RED}FAILED${NC}"
        echo "    Need at least 5GB free"
        FAILED=$((FAILED + 1))
    elif [ "$FREE_DISK" -lt 10 ]; then
        echo -e "${YELLOW}OK${NC}"
        echo "    Acceptable, but consider cleaning up"
        PASSED=$((PASSED + 1))
    else
        echo -e "${GREEN}EXCELLENT${NC}"
        PASSED=$((PASSED + 1))
    fi
    echo ""
fi

# Check 4: Required Ports
echo "✓ Checking if ports are accessible..."
for PORT in 80 443; do
    echo -n "  Port $PORT: "
    if timeout 5 bash -c ">/dev/tcp/$SERVER_IP/$PORT" 2>/dev/null; then
        echo -e "${GREEN}OPEN${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}CLOSED${NC}"
        echo "    Action: Open port $PORT in Lightsail firewall"
        FAILED=$((FAILED + 1))
    fi
done
echo ""

# Check 5: Local Docker files
echo "✓ Checking local files..."
REQUIRED_FILES=("docker-compose.prod.yml" "Dockerfile" "schema.sql" "nginx.conf" "main.go")
for FILE in "${REQUIRED_FILES[@]}"; do
    echo -n "  $FILE: "
    if [ -f "$FILE" ]; then
        echo -e "${GREEN}✓${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC}"
        FAILED=$((FAILED + 1))
    fi
done
echo ""

# Summary
echo "========================================="
echo "  Summary"
echo "========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "You're ready to deploy. Run:"
    echo "  ./deploy-lightsail.sh $SERVER_IP"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    echo ""
    echo "Please fix the issues above before deploying."
    echo ""
    echo "Common fixes:"
    echo "1. DNS: Go to your domain registrar and add/update A record"
    echo "2. Ports: Go to Lightsail console → Networking → Add rules for 80, 443"
    echo "3. SSH: Check your SSH key is added to Lightsail instance"
    echo ""
    exit 1
fi
