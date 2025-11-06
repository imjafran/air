#!/bin/bash

# Air - Quick Update Script
# Pull latest changes and restart service

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Updating Air...${NC}"

# Pull latest changes
echo -e "${YELLOW}Pulling from Git...${NC}"
git pull

# Rebuild
echo -e "${YELLOW}Building application...${NC}"
go build -o air main.go

# Restart service
echo -e "${YELLOW}Restarting service...${NC}"
sudo systemctl restart air

# Check status
sleep 2
if sudo systemctl is-active --quiet air; then
    echo -e "${GREEN}✓ Service restarted successfully${NC}"
    echo ""
    echo "Status:"
    sudo systemctl status air --no-pager -l
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check logs with: sudo journalctl -u air -n 50"
    exit 1
fi

echo ""
echo -e "${GREEN}Update complete!${NC}"
