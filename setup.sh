#!/bin/bash

# Air - Automated Setup Script
# This script will install and configure everything needed for Air
# Compatible with: Ubuntu 24.04 LTS, Ubuntu 22.04 LTS, Ubuntu 20.04 LTS
# Minimum requirements: 1GB RAM, 10GB disk space

set -e

# Disable interactive prompts during apt operations
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Air - Automated Setup Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do not run this script as root (without sudo)${NC}"
    echo "Run as: ./setup.sh"
    exit 1
fi

# Get configuration
echo -e "${YELLOW}MySQL Configuration:${NC}"
read -p "MySQL root password: " -s MYSQL_ROOT_PASSWORD
echo ""
read -p "MySQL air_user password: " -s MYSQL_PASSWORD
echo ""

# Auto-detect domain from hostname or use default
DOMAIN=$(hostname -f 2>/dev/null || echo "air.arraystory.com")
echo -e "${GREEN}Using domain: ${DOMAIN}${NC}"

# Auto-generate API token
API_TOKEN=$(openssl rand -hex 32)
echo -e "${GREEN}Generated API Token: ${API_TOKEN}${NC}"
echo ""

echo -e "${YELLOW}Installing dependencies...${NC}"

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Go
echo "Installing Go..."
if ! command -v go &> /dev/null; then
    sudo snap install go --classic
    export PATH=$PATH:/snap/bin
else
    echo "Go already installed"
fi

# Install MySQL
echo "Installing MySQL..."
if ! command -v mysql &> /dev/null; then
    export DEBIAN_FRONTEND=noninteractive

    # Clean up any previous failed installations
    echo "Cleaning up previous installation attempts..."
    sudo pkill -9 mysqld 2>/dev/null || true
    sudo apt remove --purge mysql-server mysql-server-* mysql-client mysql-common -y 2>/dev/null || true
    sudo apt autoremove -y
    sudo apt autoclean
    sudo rm -rf /var/lib/mysql /etc/mysql /var/log/mysql

    # Create MySQL config directory for low-memory optimization
    sudo mkdir -p /etc/mysql/mysql.conf.d

    # Create low-memory MySQL configuration BEFORE installation
    echo "Creating low-memory MySQL configuration..."
    sudo tee /etc/mysql/mysql.conf.d/low-memory.cnf > /dev/null << 'EOF'
[mysqld]
# Low memory optimization for small servers (512MB - 1GB RAM)
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

    # Install MySQL with preconfiguration
    echo "Installing MySQL (this may take a few minutes)..."
    sudo apt install -y mysql-server

    # Force stop any running instances
    sudo pkill -9 mysqld 2>/dev/null || true
    sleep 2

    # Initialize MySQL data directory if needed
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        echo "Initializing MySQL data directory..."
        sudo mysqld --initialize-insecure --user=mysql 2>/dev/null || true
    fi

    # Start MySQL with systemd
    echo "Starting MySQL..."
    sudo systemctl enable mysql
    sudo systemctl start mysql

    # Wait for MySQL to be ready with more patience
    echo "Waiting for MySQL to start (this may take up to 2 minutes)..."
    for i in {1..60}; do
        if sudo mysqladmin ping -h localhost --silent 2>/dev/null; then
            echo -e "${GREEN}MySQL is ready${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""

    # Check if MySQL is actually running
    if ! sudo systemctl is-active --quiet mysql; then
        echo -e "${RED}MySQL failed to start. Attempting recovery...${NC}"

        # Check for port conflicts
        sudo lsof -i :3306 2>/dev/null || true

        # Try starting with increased timeout
        sudo systemctl stop mysql 2>/dev/null || true
        sleep 3
        sudo systemctl start mysql
        sleep 5

        if ! sudo systemctl is-active --quiet mysql; then
            echo -e "${RED}Failed to start MySQL. Check logs:${NC}"
            echo "  sudo journalctl -u mysql -n 50"
            exit 1
        fi
    fi

    # Set root password
    echo "Configuring MySQL root password..."

    # Try without password first (fresh install)
    if sudo mysql -e "SELECT 1;" 2>/dev/null; then
        sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"
        sudo mysql -e "FLUSH PRIVILEGES;"
    else
        # Try with the password (might already be set)
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" 2>/dev/null || \
        sudo mysqladmin -u root password "$MYSQL_ROOT_PASSWORD" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ MySQL installed and configured${NC}"
else
    echo "MySQL already installed"

    # Test if we can connect with provided password
    if ! mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" 2>/dev/null; then
        echo -e "${RED}Error: Cannot connect to MySQL with provided password${NC}"
        echo "Please ensure the MySQL root password is correct."
        exit 1
    fi

    # Ensure low-memory config exists
    if [ ! -f /etc/mysql/mysql.conf.d/low-memory.cnf ]; then
        echo "Adding low-memory configuration..."
        sudo tee /etc/mysql/mysql.conf.d/low-memory.cnf > /dev/null << 'EOF'
[mysqld]
performance_schema = OFF
innodb_buffer_pool_size = 64M
innodb_log_buffer_size = 4M
max_connections = 50
EOF
        sudo systemctl restart mysql
        sleep 3
    fi
    sudo systemctl start mysql 2>/dev/null || true
fi

# Install Nginx
echo "Installing Nginx..."
if ! command -v nginx &> /dev/null; then
    sudo apt install -y nginx
else
    echo "Nginx already installed"
fi

# Install Certbot
echo "Installing Certbot..."
if ! command -v certbot &> /dev/null; then
    sudo apt install -y certbot python3-certbot-nginx
else
    echo "Certbot already installed"
fi

echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Verify MySQL is running
echo -e "${YELLOW}Verifying MySQL status...${NC}"
if ! sudo systemctl is-active --quiet mysql; then
    echo -e "${YELLOW}MySQL service is not running, attempting to start...${NC}"

    # Kill any hung processes
    sudo pkill -9 mysqld 2>/dev/null || true
    sleep 2

    # Try to start
    sudo systemctl start mysql
    sleep 5

    # Check again
    if ! sudo systemctl is-active --quiet mysql; then
        echo -e "${RED}Failed to start MySQL.${NC}"
        echo ""
        echo "Checking for issues..."
        echo "Memory available:"
        free -h
        echo ""
        echo "MySQL status:"
        sudo systemctl status mysql --no-pager || true
        echo ""
        echo "Recent MySQL logs:"
        sudo journalctl -u mysql -n 30 --no-pager || true
        echo ""
        echo -e "${RED}Setup cannot continue without MySQL.${NC}"
        echo "Possible fixes:"
        echo "1. Increase server memory (recommend 1GB+)"
        echo "2. Manually configure MySQL: sudo dpkg --configure -a"
        echo "3. Check disk space: df -h"
        exit 1
    fi
fi

echo -e "${GREEN}✓ MySQL is running${NC}"

# Set up database
echo -e "${YELLOW}Setting up database...${NC}"

# Create database and user (with error handling for existing user)
mysql -u root -p"$MYSQL_ROOT_PASSWORD" << MYSQL_SCRIPT 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS air_production;
MYSQL_SCRIPT

# Try to create user, or update password if exists
mysql -u root -p"$MYSQL_ROOT_PASSWORD" << MYSQL_SCRIPT 2>/dev/null
CREATE USER IF NOT EXISTS 'air_user'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
MYSQL_SCRIPT

# If user already exists, update password
if [ $? -ne 0 ]; then
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" << MYSQL_SCRIPT 2>/dev/null || true
ALTER USER 'air_user'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
MYSQL_SCRIPT
fi

# Grant privileges
mysql -u root -p"$MYSQL_ROOT_PASSWORD" << MYSQL_SCRIPT
GRANT ALL PRIVILEGES ON air_production.* TO 'air_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Load schema
echo "Loading database schema..."
if mysql -u root -p"$MYSQL_ROOT_PASSWORD" air_production < schema.sql 2>/dev/null; then
    echo -e "${GREEN}✓ Schema loaded${NC}"
else
    echo -e "${YELLOW}⚠ Schema already exists or failed to load${NC}"
fi

# Insert initial data
mysql -u root -p"$MYSQL_ROOT_PASSWORD" air_production << MYSQL_SCRIPT
INSERT INTO air_rooms (name, description, is_active) VALUES ('demo', 'Production demo room', TRUE) ON DUPLICATE KEY UPDATE name=name;
INSERT INTO air_room_domains (room_id, domain) VALUES (1, '$DOMAIN') ON DUPLICATE KEY UPDATE domain='$DOMAIN';
INSERT INTO air_api_tokens (token, room_id, name, is_active) VALUES ('$API_TOKEN', 1, 'Production API Token', TRUE) ON DUPLICATE KEY UPDATE token='$API_TOKEN';
MYSQL_SCRIPT

echo -e "${GREEN}✓ Database configured${NC}"
echo ""

# Create environment file
echo -e "${YELLOW}Creating environment configuration...${NC}"
cat > .env << EOF
DB_HOST=localhost
DB_PORT=3306
DB_USER=air_user
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=air_production
AIR_PORT=8181
EOF

echo -e "${GREEN}✓ Environment configured${NC}"
echo ""

# Build Go application
echo -e "${YELLOW}Building Go application...${NC}"
go build -o air main.go
echo -e "${GREEN}✓ Application built${NC}"
echo ""

# Create systemd service
echo -e "${YELLOW}Creating systemd service...${NC}"
sudo tee /etc/systemd/system/air.service > /dev/null << EOF
[Unit]
Description=Air WebSocket Server
After=network.target mysql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD
ExecStart=$PWD/air
Restart=always
RestartSec=3
Environment="DB_HOST=localhost"
Environment="DB_PORT=3306"
Environment="DB_USER=air_user"
Environment="DB_PASSWORD=$MYSQL_PASSWORD"
Environment="DB_NAME=air_production"
Environment="AIR_PORT=8181"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable air
sudo systemctl start air

echo -e "${GREEN}✓ Service started${NC}"
echo ""

# Configure Nginx
echo -e "${YELLOW}Configuring Nginx...${NC}"
sudo tee /etc/nginx/sites-available/air > /dev/null << 'EOF'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        root PWD_PLACEHOLDER/public;
        try_files $uri $uri/ /index.html;
    }

    location /ws {
        proxy_pass http://localhost:8181;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    location /emit {
        proxy_pass http://localhost:8181;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /air.js {
        alias PWD_PLACEHOLDER/public/air.prod.js;
        add_header Content-Type application/javascript;
    }
}
EOF

# Replace placeholders
sudo sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /etc/nginx/sites-available/air
sudo sed -i "s|PWD_PLACEHOLDER|$PWD|g" /etc/nginx/sites-available/air

# Enable site
sudo ln -sf /etc/nginx/sites-available/air /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload
sudo nginx -t
sudo systemctl reload nginx

echo -e "${GREEN}✓ Nginx configured${NC}"
echo ""

# SSL Certificate (optional)
echo ""
echo -e "${YELLOW}SSL Certificate Setup:${NC}"
echo "To set up SSL later, run: sudo certbot --nginx -d $DOMAIN"
echo -e "${YELLOW}Skipping SSL for now${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Service Status: ${GREEN}$(sudo systemctl is-active air)${NC}"
echo ""
echo -e "${YELLOW}Important Information (Save this!):${NC}"
echo ""
echo "Domain: $DOMAIN"
echo "API Token: $API_TOKEN"
echo "Room: demo"
echo "MySQL User: air_user"
echo "MySQL Password: $MYSQL_PASSWORD"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Set up SSL: sudo certbot --nginx -d $DOMAIN --email your-email@example.com"
echo "2. Point DNS A record for $DOMAIN to this server's IP"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "Check service: sudo systemctl status air"
echo "View logs: sudo journalctl -u air -f"
echo "Restart: sudo systemctl restart air"
echo "Update: cd ~/air && ./update.sh"
echo ""
echo -e "${GREEN}Visit: http://$DOMAIN (or https:// after SSL setup)${NC}"
echo ""
