#!/bin/bash

# Air - Fix Broken MySQL Installation
# Use this when MySQL installation fails completely

set +e  # Don't exit on errors

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Fix Broken MySQL Installation${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do not run this script as root${NC}"
    exit 1
fi

# Check available memory
echo -e "${YELLOW}Checking system resources...${NC}"
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
echo "Total RAM: ${TOTAL_MEM}MB"

if [ "$TOTAL_MEM" -lt 512 ]; then
    echo -e "${RED}WARNING: Server has less than 512MB RAM${NC}"
    echo "MySQL may not run reliably. Consider upgrading to 1GB+"
    echo ""
fi

# Check disk space
DISK_FREE=$(df / | tail -1 | awk '{print $4}')
echo "Free disk space: $(df -h / | tail -1 | awk '{print $4}')"

if [ "$DISK_FREE" -lt 1000000 ]; then
    echo -e "${RED}WARNING: Less than 1GB free disk space${NC}"
    echo "MySQL installation may fail"
    echo ""
fi

echo ""
echo -e "${YELLOW}This will completely remove and reinstall MySQL${NC}"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# Get MySQL password
echo ""
read -p "Enter MySQL root password to set: " -s MYSQL_ROOT_PASSWORD
echo ""

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    echo -e "${RED}Password cannot be empty${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 1: Stopping all MySQL processes...${NC}"
sudo systemctl stop mysql 2>/dev/null || true
sudo systemctl stop mysql.service 2>/dev/null || true
sleep 2
sudo pkill -9 mysqld 2>/dev/null || true
sleep 2

echo -e "${YELLOW}Step 2: Fixing broken dpkg state...${NC}"
sudo dpkg --configure -a 2>/dev/null || true

echo -e "${YELLOW}Step 3: Removing broken MySQL packages...${NC}"
sudo apt-mark unhold mysql-server mysql-server-8.0 mysql-client 2>/dev/null || true
sudo apt remove --purge -y mysql-server mysql-server-* mysql-client mysql-common mysql-client-core-* mysql-server-core-* 2>/dev/null || true
sudo apt autoremove -y 2>/dev/null || true
sudo apt autoclean 2>/dev/null || true

echo -e "${YELLOW}Step 4: Removing MySQL data and config files...${NC}"
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/lib/mysql-files
sudo rm -rf /var/lib/mysql-keyring
sudo rm -rf /etc/mysql
sudo rm -rf /var/log/mysql
sudo rm -rf /usr/lib/mysql
sudo rm -rf /usr/share/mysql
sudo rm -rf /tmp/mysql*
sudo rm -rf /var/tmp/mysql*

echo -e "${YELLOW}Step 5: Cleaning package manager...${NC}"
sudo apt clean
sudo apt update
sudo apt --fix-broken install -y

# Create swap file if not exists and low memory
if [ "$TOTAL_MEM" -lt 1024 ]; then
    if [ ! -f /swapfile ]; then
        echo -e "${YELLOW}Step 6: Creating swap file (low memory detected)...${NC}"
        sudo fallocate -l 1G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        echo -e "${GREEN}✓ Swap file created${NC}"
    else
        echo -e "${GREEN}✓ Swap file already exists${NC}"
        sudo swapon /swapfile 2>/dev/null || true
    fi
fi

echo ""
echo -e "${YELLOW}Step 7: Creating optimized MySQL configuration...${NC}"
sudo mkdir -p /etc/mysql/mysql.conf.d
sudo mkdir -p /etc/mysql/conf.d

# Create my.cnf
sudo tee /etc/mysql/my.cnf > /dev/null << 'EOF'
[mysqld_safe]
socket = /var/run/mysqld/mysqld.sock
nice = 0

[mysqld]
user = mysql
pid-file = /var/run/mysqld/mysqld.pid
socket = /var/run/mysqld/mysqld.sock
port = 3306
basedir = /usr
datadir = /var/lib/mysql
tmpdir = /tmp
lc-messages-dir = /usr/share/mysql
skip-external-locking
bind-address = 127.0.0.1
key_buffer_size = 8M
max_allowed_packet = 16M
thread_stack = 192K
thread_cache_size = 4
myisam_recover_options = BACKUP
query_cache_limit = 1M
query_cache_size = 0
query_cache_type = 0
log_error = /var/log/mysql/error.log
expire_logs_days = 10
max_binlog_size = 100M

[mysqldump]
quick
quote-names
max_allowed_packet = 16M

[mysql]

[isamchk]
key_buffer_size = 16M

!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mysql.conf.d/
EOF

# Create low-memory config
sudo tee /etc/mysql/mysql.conf.d/low-memory.cnf > /dev/null << 'EOF'
[mysqld]
# Ultra-low memory configuration
performance_schema = OFF
innodb_buffer_pool_size = 64M
innodb_log_buffer_size = 4M
innodb_log_file_size = 32M
max_connections = 25
table_open_cache = 256
thread_cache_size = 4
query_cache_size = 0
query_cache_type = 0
key_buffer_size = 8M
tmp_table_size = 8M
max_heap_table_size = 8M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_buffer_pool_instances = 1
innodb_read_io_threads = 2
innodb_write_io_threads = 2
EOF

echo -e "${GREEN}✓ Configuration created${NC}"

echo ""
echo -e "${YELLOW}Step 8: Installing MySQL (this may take 5-10 minutes)...${NC}"
echo "Please be patient..."

# Install MySQL
if ! sudo apt install -y mysql-server; then
    echo -e "${RED}Failed to install MySQL${NC}"
    echo ""
    echo "Diagnostics:"
    echo "Last 20 lines of apt log:"
    tail -20 /var/log/apt/term.log 2>/dev/null || echo "Cannot read apt log"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 9: Creating MySQL data directory...${NC}"
sudo mkdir -p /var/lib/mysql
sudo chown -R mysql:mysql /var/lib/mysql
sudo chmod 750 /var/lib/mysql

sudo mkdir -p /var/run/mysqld
sudo chown -R mysql:mysql /var/run/mysqld
sudo chmod 755 /var/run/mysqld

sudo mkdir -p /var/log/mysql
sudo chown -R mysql:mysql /var/log/mysql
sudo touch /var/log/mysql/error.log
sudo chown mysql:mysql /var/log/mysql/error.log

# Initialize data directory if empty
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo -e "${YELLOW}Initializing MySQL data directory...${NC}"
    sudo mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql 2>/dev/null || true
fi

echo ""
echo -e "${YELLOW}Step 10: Starting MySQL...${NC}"

# Enable and start
sudo systemctl enable mysql
sudo systemctl start mysql

# Wait with patience
echo "Waiting for MySQL to start (up to 3 minutes)..."
for i in {1..90}; do
    if sudo mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo -e "${GREEN}MySQL started successfully!${NC}"
        break
    fi
    if [ $((i % 10)) -eq 0 ]; then
        echo "Still waiting... ($i/90)"
    fi
    sleep 2
done

# Final check
if ! sudo systemctl is-active --quiet mysql; then
    echo -e "${RED}MySQL failed to start${NC}"
    echo ""
    echo "Checking error log:"
    sudo tail -50 /var/log/mysql/error.log 2>/dev/null || echo "Cannot read error log"
    echo ""
    echo "Checking system logs:"
    sudo journalctl -u mysql -n 30 --no-pager
    echo ""
    echo -e "${RED}MySQL installation failed${NC}"
    echo ""
    echo "Possible issues:"
    echo "1. Insufficient memory (need 1GB+)"
    echo "2. Insufficient disk space"
    echo "3. Corrupted installation"
    echo ""
    echo "Try rebooting the server and running this script again:"
    echo "  sudo reboot"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 11: Securing MySQL...${NC}"

# Try to set root password
if sudo mysql -e "SELECT 1;" 2>/dev/null; then
    sudo mysql << MYSQL_SCRIPT
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    echo -e "${GREEN}✓ MySQL secured${NC}"
else
    echo -e "${YELLOW}⚠ Could not set root password (will try again)${NC}"
fi

# Verify we can connect
echo ""
echo -e "${YELLOW}Step 12: Verifying installation...${NC}"

if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" 2>/dev/null; then
    VERSION=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" 2>/dev/null | tail -1)
    echo -e "${GREEN}✓ MySQL $VERSION is working${NC}"
else
    echo -e "${RED}✗ Cannot connect to MySQL${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MySQL Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}✓ MySQL is installed and running${NC}"
echo -e "${GREEN}✓ Root password is set${NC}"
echo ""
echo "Next steps:"
echo "1. Run: ./setup.sh"
echo "   (Enter the same MySQL root password when prompted)"
echo ""
echo "Service management:"
echo "  Check status: sudo systemctl status mysql"
echo "  View logs: sudo tail -f /var/log/mysql/error.log"
echo ""
