#!/bin/bash

# Nuclear option - Complete system cleanup and minimal MySQL install
# Run this if everything else fails

set +e

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}========================================${NC}"
echo -e "${RED}  NUCLEAR OPTION - Complete Reset${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}This will:${NC}"
echo "1. Kill all MySQL processes"
echo "2. Remove EVERYTHING MySQL-related"
echo "3. Clean package manager"
echo "4. Reboot if needed"
echo "5. Install fresh minimal MySQL"
echo ""
echo -e "${RED}WARNING: This will delete all MySQL databases!${NC}"
echo ""
read -p "Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled"
    exit 1
fi

echo ""
read -p "MySQL root password to set: " -s MYSQL_ROOT_PASSWORD
echo ""

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    echo -e "${RED}Password required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[1/10] Killing all MySQL processes...${NC}"
sudo killall -9 mysqld mysqld_safe 2>/dev/null || true
sudo pkill -9 mysql 2>/dev/null || true
sleep 3

echo -e "${YELLOW}[2/10] Stopping services...${NC}"
sudo systemctl stop mysql 2>/dev/null || true
sudo systemctl stop mysql.service 2>/dev/null || true
sudo systemctl disable mysql 2>/dev/null || true
sleep 2

echo -e "${YELLOW}[3/10] Removing all MySQL packages...${NC}"
sudo apt-mark unhold mysql-* 2>/dev/null || true
sudo apt remove --purge -y mysql-* 2>/dev/null || true
sudo apt remove --purge -y mariadb-* 2>/dev/null || true
sudo apt autoremove -y
sudo apt autoclean

echo -e "${YELLOW}[4/10] Deleting all MySQL files...${NC}"
sudo rm -rf /var/lib/mysql*
sudo rm -rf /etc/mysql*
sudo rm -rf /var/log/mysql*
sudo rm -rf /usr/lib/mysql*
sudo rm -rf /usr/share/mysql*
sudo rm -rf /tmp/mysql*
sudo rm -rf /var/tmp/mysql*
sudo rm -rf /run/mysqld*
sudo rm -rf /var/run/mysqld*

echo -e "${YELLOW}[5/10] Fixing package manager...${NC}"
sudo dpkg --configure -a
sudo apt --fix-broken install -y
sudo apt clean
sudo apt update

echo -e "${YELLOW}[6/10] Checking system resources...${NC}"
echo "RAM:"
free -h | grep Mem:
echo "Disk:"
df -h / | tail -1

TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 512 ]; then
    echo -e "${RED}ERROR: Less than 512MB RAM${NC}"
    echo "MySQL requires at least 512MB RAM"
    echo ""
    echo "Options:"
    echo "1. Upgrade VPS to 1GB+ RAM"
    echo "2. Use SQLite instead (requires code changes)"
    echo "3. Use external managed database"
    exit 1
fi

# Create swap if low memory
if [ "$TOTAL_MEM" -lt 1024 ] && [ ! -f /swapfile ]; then
    echo -e "${YELLOW}[7/10] Creating 2GB swap file (low RAM)...${NC}"
    sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo -e "${GREEN}Swap enabled${NC}"
else
    echo -e "${YELLOW}[7/10] Skipping swap (sufficient RAM or swap exists)${NC}"
fi

echo -e "${YELLOW}[8/10] Installing MySQL...${NC}"
sudo apt install -y mysql-server

if [ $? -ne 0 ]; then
    echo -e "${RED}Installation failed${NC}"
    echo ""
    echo "Last error:"
    tail -20 /var/log/apt/term.log 2>/dev/null
    echo ""
    echo "Try rebooting: sudo reboot"
    exit 1
fi

echo -e "${YELLOW}[9/10] Configuring MySQL...${NC}"

# Create minimal config
sudo mkdir -p /etc/mysql/mysql.conf.d
sudo tee /etc/mysql/mysql.conf.d/minimal.cnf > /dev/null << 'EOF'
[mysqld]
performance_schema=OFF
innodb_buffer_pool_size=64M
max_connections=25
EOF

# Fix permissions
sudo mkdir -p /var/run/mysqld
sudo chown mysql:mysql /var/run/mysqld
sudo chmod 755 /var/run/mysqld

sudo mkdir -p /var/log/mysql
sudo chown mysql:mysql /var/log/mysql

# Start MySQL
sudo systemctl enable mysql
sudo systemctl start mysql

echo "Waiting for MySQL..."
sleep 5

for i in {1..30}; do
    if sudo mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo -e "${GREEN}MySQL is running${NC}"
        break
    fi
    sleep 2
done

if ! sudo systemctl is-active --quiet mysql; then
    echo -e "${RED}MySQL failed to start${NC}"
    echo ""
    sudo journalctl -u mysql -n 50 --no-pager
    echo ""
    echo "You may need to reboot: sudo reboot"
    exit 1
fi

echo -e "${YELLOW}[10/10] Setting root password...${NC}"

# Set password
if sudo mysql -e "SELECT 1;" 2>/dev/null; then
    sudo mysql << MYSQL_SCRIPT
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    echo -e "${GREEN}Password set${NC}"
fi

# Verify
if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" 2>/dev/null; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  SUCCESS!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "MySQL is installed and working"
    echo ""
    echo "Next: Run ./setup.sh with the same password"
    echo ""
else
    echo -e "${RED}Cannot connect${NC}"
    exit 1
fi
