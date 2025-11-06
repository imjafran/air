#!/bin/bash

# Skip SSL and just get the app running with HTTP
# Use this if SSL is causing issues

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  Skip SSL - Use HTTP Only"
echo "========================================="
echo ""

DOMAIN="air.arraystory.com"

# Check if containers are running
if ! docker compose -f docker-compose.prod.yml ps | grep -q "Up"; then
    echo "Starting containers..."
    docker compose -f docker-compose.prod.yml up -d
    sleep 5
fi

# Check nginx
echo "Checking nginx..."
if docker compose -f docker-compose.prod.yml exec nginx nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✓ Nginx is running${NC}"
else
    echo "Restarting nginx..."
    docker compose -f docker-compose.prod.yml restart nginx
    sleep 3
fi

# Get server IP
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}✓ App is running (HTTP only)${NC}"
echo ""
echo "Access your app:"
echo "  • http://${DOMAIN}"
echo "  • http://${SERVER_IP}"
echo ""
echo -e "${YELLOW}Note: Using HTTP (not secure)${NC}"
echo "Set up SSL later with: ./setup-ssl.sh"
echo ""
