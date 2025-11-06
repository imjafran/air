#!/bin/bash

# Quick MySQL diagnostic script

echo "========================================="
echo "  MySQL Diagnostics"
echo "========================================="
echo ""

echo "1. Package status:"
dpkg -l | grep mysql

echo ""
echo "2. Service status:"
sudo systemctl status mysql --no-pager -l || true

echo ""
echo "3. Memory available:"
free -h

echo ""
echo "4. Disk space:"
df -h /

echo ""
echo "5. MySQL error log (last 30 lines):"
if [ -f /var/log/mysql/error.log ]; then
    sudo tail -30 /var/log/mysql/error.log
else
    echo "Error log not found"
fi

echo ""
echo "6. System logs for MySQL:"
sudo journalctl -u mysql -n 20 --no-pager || true

echo ""
echo "7. MySQL processes:"
ps aux | grep mysql | grep -v grep || echo "No MySQL processes running"

echo ""
echo "8. Port 3306 status:"
sudo lsof -i :3306 || echo "Port 3306 not in use"

echo ""
echo "========================================="
echo "  Recommendations"
echo "========================================="
echo ""

TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 512 ]; then
    echo "⚠ WARNING: Less than 512MB RAM"
    echo "  MySQL needs at least 512MB, recommend 1GB+"
fi

DISK_FREE=$(df / | tail -1 | awk '{print $4}')
if [ "$DISK_FREE" -lt 1000000 ]; then
    echo "⚠ WARNING: Less than 1GB free disk space"
fi

if dpkg -l | grep mysql | grep -q "^iF"; then
    echo "⚠ MySQL packages are in broken state"
    echo "  Run: ./fix-broken-mysql.sh"
fi

echo ""
echo "To fix MySQL completely:"
echo "  ./fix-broken-mysql.sh"
echo ""
