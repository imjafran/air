#!/bin/bash

# Complete VPS Cleanup Script
# Removes all Air installation files and MySQL

set +e

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Clean VPS - Remove Everything${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "This will remove:"
echo "  • All Air files"
echo "  • MySQL and all databases"
echo "  • Nginx configuration"
echo "  • Go installation (optional)"
echo "  • Systemd services"
echo ""
echo -e "${RED}WARNING: This cannot be undone!${NC}"
echo ""
read -p "Type 'DELETE' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting cleanup...${NC}"
echo ""

# Stop all services
echo "Stopping services..."
sudo systemctl stop air 2>/dev/null || true
sudo systemctl stop mysql 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# Kill processes
echo "Killing processes..."
sudo killall -9 air 2>/dev/null || true
sudo killall -9 mysqld 2>/dev/null || true
sudo pkill -9 mysql 2>/dev/null || true

# Remove Air service
echo "Removing Air service..."
sudo systemctl disable air 2>/dev/null || true
sudo rm -f /etc/systemd/system/air.service
sudo systemctl daemon-reload

# Remove Air files
echo "Removing Air files..."
rm -rf ~/air
rm -rf ~/air-deploy.tar.gz

# Remove MySQL
echo "Removing MySQL..."
sudo apt-mark unhold mysql-* 2>/dev/null || true
sudo apt remove --purge -y mysql-* mariadb-* 2>/dev/null || true
sudo apt autoremove -y
sudo rm -rf /var/lib/mysql*
sudo rm -rf /etc/mysql*
sudo rm -rf /var/log/mysql*
sudo rm -rf /usr/lib/mysql*
sudo rm -rf /usr/share/mysql*
sudo rm -rf /tmp/mysql*
sudo rm -rf /var/tmp/mysql*

# Remove Nginx Air config (keep Nginx itself)
echo "Removing Nginx Air configuration..."
sudo rm -f /etc/nginx/sites-available/air
sudo rm -f /etc/nginx/sites-enabled/air
sudo systemctl reload nginx 2>/dev/null || true

# Optional: Remove Go
read -p "Remove Go? (y/n): " REMOVE_GO
if [ "$REMOVE_GO" = "y" ]; then
    echo "Removing Go..."
    sudo snap remove go 2>/dev/null || true
    sudo apt remove --purge -y golang-* 2>/dev/null || true
fi

# Clean package manager
echo "Cleaning package manager..."
sudo dpkg --configure -a
sudo apt --fix-broken install -y
sudo apt clean
sudo apt autoremove -y

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  VPS Cleaned${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Removed:"
echo "  ✓ Air application and files"
echo "  ✓ MySQL and all databases"
echo "  ✓ Nginx Air configuration"
echo "  ✓ Systemd services"
echo ""
echo "Kept:"
echo "  • Nginx (base installation)"
echo "  • Certbot"
echo "  • System packages"
echo ""
echo "To start fresh:"
echo "  1. Upload/clone Air files"
echo "  2. Run: ./setup.sh"
echo ""
echo "Or completely rebuild VPS from your hosting provider."
echo ""
