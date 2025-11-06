#!/bin/bash

# Air - Health Check Script
# Quickly verify if everything is running correctly

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  Air Health Check"
echo "========================================="
echo ""

# Check Go
echo -n "Go: "
if command -v go &> /dev/null; then
    VERSION=$(go version | awk '{print $3}')
    echo -e "${GREEN}✓ Installed ($VERSION)${NC}"
else
    echo -e "${RED}✗ Not installed${NC}"
fi

# Check MySQL
echo -n "MySQL: "
if command -v mysql &> /dev/null; then
    if systemctl is-active --quiet mysql 2>/dev/null || pgrep -x mysqld > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Installed but not running${NC}"
    fi
else
    echo -e "${RED}✗ Not installed${NC}"
fi

# Check Nginx
echo -n "Nginx: "
if command -v nginx &> /dev/null; then
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Installed but not running${NC}"
    fi
else
    echo -e "${RED}✗ Not installed${NC}"
fi

# Check Air Service
echo -n "Air Service: "
if systemctl list-unit-files | grep -q "air.service"; then
    if systemctl is-active --quiet air; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Service exists but not running${NC}"
        echo "  Start with: sudo systemctl start air"
    fi
else
    echo -e "${YELLOW}⚠ Service not configured${NC}"
    echo "  Run ./setup.sh to configure"
fi

echo ""
echo "========================================="
echo "  Port Status"
echo "========================================="
echo ""

# Check port 8181 (Air)
echo -n "Port 8181 (Air): "
if lsof -Pi :8181 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Listening${NC}"
else
    echo -e "${RED}✗ Not listening${NC}"
fi

# Check port 80 (Nginx)
echo -n "Port 80 (HTTP): "
if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Listening${NC}"
else
    echo -e "${YELLOW}⚠ Not listening${NC}"
fi

# Check port 443 (Nginx SSL)
echo -n "Port 443 (HTTPS): "
if lsof -Pi :443 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Listening${NC}"
else
    echo -e "${YELLOW}⚠ Not listening (SSL not configured)${NC}"
fi

# Check port 3306 (MySQL)
echo -n "Port 3306 (MySQL): "
if lsof -Pi :3306 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Listening${NC}"
else
    echo -e "${RED}✗ Not listening${NC}"
fi

echo ""
echo "========================================="
echo "  Database"
echo "========================================="
echo ""

# Check if .env exists
if [ -f .env ]; then
    echo -e "${GREEN}✓ .env file exists${NC}"

    # Source .env
    export $(cat .env | grep -v '^#' | xargs)

    # Try to connect to database
    echo -n "Database Connection: "
    if mysql -u "$DB_USER" -p"$DB_PASSWORD" -h "$DB_HOST" -e "USE $DB_NAME; SELECT 1;" &> /dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"

        # Check tables
        echo -n "Tables: "
        TABLES=$(mysql -u "$DB_USER" -p"$DB_PASSWORD" -h "$DB_HOST" "$DB_NAME" -e "SHOW TABLES;" 2>/dev/null | grep -c "air_")
        if [ "$TABLES" -ge 3 ]; then
            echo -e "${GREEN}✓ Found $TABLES tables${NC}"
        else
            echo -e "${YELLOW}⚠ Found $TABLES tables (expected 3+)${NC}"
        fi

        # Check rooms
        echo -n "Rooms: "
        ROOMS=$(mysql -u "$DB_USER" -p"$DB_PASSWORD" -h "$DB_HOST" "$DB_NAME" -e "SELECT COUNT(*) FROM air_rooms;" 2>/dev/null | tail -1)
        if [ "$ROOMS" -gt 0 ]; then
            echo -e "${GREEN}✓ Found $ROOMS room(s)${NC}"
        else
            echo -e "${YELLOW}⚠ No rooms found${NC}"
        fi
    else
        echo -e "${RED}✗ Cannot connect${NC}"
        echo "  Check credentials in .env file"
    fi
else
    echo -e "${RED}✗ .env file not found${NC}"
    echo "  Run ./setup.sh to create"
fi

echo ""
echo "========================================="
echo "  System Resources"
echo "========================================="
echo ""

# Memory
echo "Memory:"
free -h | grep "Mem:" | awk '{print "  Total: " $2 ", Used: " $3 ", Free: " $4}'

# Disk
echo ""
echo "Disk:"
df -h / | tail -1 | awk '{print "  Total: " $2 ", Used: " $3 " (" $5 "), Free: " $4}'

# Load average
echo ""
echo "Load Average:"
uptime | awk '{print "  " $10 " " $11 " " $12}'

echo ""
echo "========================================="
echo "  Recent Logs"
echo "========================================="
echo ""

if systemctl list-unit-files | grep -q "air.service"; then
    echo "Last 5 Air service logs:"
    sudo journalctl -u air -n 5 --no-pager 2>/dev/null || echo "  Cannot read logs (need sudo)"
else
    echo "Air service not configured"
fi

echo ""
echo "========================================="
echo "  Quick Actions"
echo "========================================="
echo ""
echo "View logs:       sudo journalctl -u air -f"
echo "Restart service: sudo systemctl restart air"
echo "Check status:    sudo systemctl status air"
echo "Test connection: curl http://localhost:8181/"
echo ""
