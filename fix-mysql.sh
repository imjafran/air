#!/bin/bash

# Air - MySQL Recovery Script
# Use this if MySQL installation failed
# Compatible with: Ubuntu 24.04 LTS, Ubuntu 22.04 LTS, Ubuntu 20.04 LTS

set -e

# Disable interactive prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  MySQL Recovery Script${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do not run this script as root${NC}"
    exit 1
fi

echo -e "${YELLOW}This script will clean up and reinstall MySQL${NC}"
echo -e "${YELLOW}Press Ctrl+C now to cancel, or Enter to continue...${NC}"
read

# Get MySQL password
read -p "MySQL root password: " -s MYSQL_ROOT_PASSWORD
echo ""

export DEBIAN_FRONTEND=noninteractive

# Stop any running MySQL processes
echo -e "${YELLOW}Stopping MySQL processes...${NC}"
sudo systemctl stop mysql 2>/dev/null || true
sudo pkill -9 mysqld 2>/dev/null || true
sleep 3

# Clean up broken installation
echo -e "${YELLOW}Removing broken MySQL installation...${NC}"
sudo apt remove --purge mysql-server mysql-server-* mysql-client mysql-common -y 2>/dev/null || true
sudo apt autoremove -y
sudo apt autoclean

# Remove data directories
echo -e "${YELLOW}Cleaning data directories...${NC}"
sudo rm -rf /var/lib/mysql
sudo rm -rf /etc/mysql
sudo rm -rf /var/log/mysql
sudo rm -rf /tmp/mysql*

# Fix any broken packages
echo -e "${YELLOW}Fixing package manager...${NC}"
sudo dpkg --configure -a
sudo apt --fix-broken install -y

# Create MySQL config directory
sudo mkdir -p /etc/mysql/mysql.conf.d

# Create low-memory configuration
echo -e "${YELLOW}Creating optimized MySQL configuration...${NC}"
sudo tee /etc/mysql/mysql.conf.d/low-memory.cnf > /dev/null << 'EOF'
[mysqld]
# Low memory optimization for small servers
performance_schema = OFF
innodb_buffer_pool_size = 64M
innodb_log_buffer_size = 4M
max_connections = 50
thread_cache_size = 4
query_cache_size = 0
query_cache_type = 0
key_buffer_size = 8M
tmp_table_size = 16M
max_heap_table_size = 16M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
EOF

# Update system packages
echo -e "${YELLOW}Updating package cache...${NC}"
sudo apt update

# Install MySQL
echo -e "${YELLOW}Installing MySQL (this will take several minutes)...${NC}"
sudo apt install -y mysql-server

# Kill any processes started during install
sudo pkill -9 mysqld 2>/dev/null || true
sleep 2

# Start MySQL
echo -e "${YELLOW}Starting MySQL...${NC}"
sudo systemctl enable mysql
sudo systemctl start mysql

# Wait for MySQL
echo -e "${YELLOW}Waiting for MySQL to start (up to 2 minutes)...${NC}"
for i in {1..60}; do
    if sudo mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo -e "${GREEN}MySQL is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Verify MySQL is running
if ! sudo systemctl is-active --quiet mysql; then
    echo -e "${RED}MySQL failed to start${NC}"
    echo ""
    echo "Diagnostics:"
    echo "Memory:"
    free -h
    echo ""
    echo "Disk space:"
    df -h
    echo ""
    echo "MySQL status:"
    sudo systemctl status mysql --no-pager
    echo ""
    echo "Recent logs:"
    sudo journalctl -u mysql -n 50 --no-pager
    exit 1
fi

# Configure root password
echo -e "${YELLOW}Setting root password...${NC}"

# Try without password first (fresh install)
if sudo mysql -e "SELECT 1;" 2>/dev/null; then
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"
    sudo mysql -e "FLUSH PRIVILEGES;"
    echo -e "${GREEN}✓ Root password set${NC}"
else
    # Try with the password (might already be set)
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" 2>/dev/null; then
        echo -e "${GREEN}✓ Root password already correct${NC}"
    else
        sudo mysqladmin -u root password "$MYSQL_ROOT_PASSWORD" 2>/dev/null || true
        echo -e "${GREEN}✓ Root password updated${NC}"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MySQL Recovery Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}MySQL is now installed and running${NC}"
echo ""
echo "You can now run: ./setup.sh"
echo ""
