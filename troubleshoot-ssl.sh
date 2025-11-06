#!/bin/bash

# Troubleshoot SSL Issues
# Run this if SSL certificate request is stuck or failing

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  SSL Troubleshooting"
echo "========================================="
echo ""

DOMAIN="air.arraystory.com"

# 1. Check DNS
echo -e "${YELLOW}[1/7] Checking DNS...${NC}"
DNS_IP=$(dig +short ${DOMAIN} A | tail -n1)
# Get IPv4 address specifically
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "Unable to get IP")

echo "Domain: ${DOMAIN}"
echo "Resolves to: ${DNS_IP}"
echo "Server IP: ${SERVER_IP}"

if [ "$DNS_IP" = "$SERVER_IP" ]; then
    echo -e "${GREEN}✓ DNS is correct${NC}"
else
    echo -e "${RED}✗ DNS mismatch!${NC}"
    echo "  Fix: Update your DNS A record to point to ${SERVER_IP}"
fi
echo ""

# 2. Check if containers are running
echo -e "${YELLOW}[2/7] Checking Docker containers...${NC}"
if docker compose -f docker-compose.prod.yml ps 2>/dev/null; then
    echo -e "${GREEN}✓ Containers found${NC}"
else
    echo -e "${RED}✗ Cannot find containers${NC}"
    echo "  Fix: Run docker compose -f docker-compose.prod.yml up -d"
fi
echo ""

# 3. Check nginx
echo -e "${YELLOW}[3/7] Checking Nginx...${NC}"
if docker compose -f docker-compose.prod.yml exec nginx nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✓ Nginx config is valid${NC}"
else
    echo -e "${RED}✗ Nginx config has errors${NC}"
    echo "  Check: docker compose -f docker-compose.prod.yml logs nginx"
fi
echo ""

# 4. Check port 80
echo -e "${YELLOW}[4/7] Checking port 80 (HTTP)...${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|404\|301\|302"; then
    echo -e "${GREEN}✓ Port 80 is accessible locally${NC}"
else
    echo -e "${RED}✗ Port 80 not accessible${NC}"
    echo "  Fix: Check firewall and nginx"
fi

# Test from outside
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${DOMAIN} 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
    echo -e "${GREEN}✓ Port 80 accessible from internet (HTTP ${HTTP_CODE})${NC}"
else
    echo -e "${RED}✗ Port 80 not accessible from internet${NC}"
    echo "  Fix: Open port 80 in Lightsail firewall"
fi
echo ""

# 5. Check port 443
echo -e "${YELLOW}[5/7] Checking port 443 (HTTPS)...${NC}"
if timeout 2 bash -c "</dev/tcp/localhost/443" 2>/dev/null; then
    echo -e "${GREEN}✓ Port 443 is open${NC}"
else
    echo -e "${YELLOW}⚠ Port 443 not listening (normal before SSL)${NC}"
fi
echo ""

# 6. Check certbot directory
echo -e "${YELLOW}[6/7] Checking certbot directories...${NC}"
if [ -d "certbot/conf" ]; then
    echo -e "${GREEN}✓ certbot/conf exists${NC}"
    if [ -d "certbot/conf/live/${DOMAIN}" ]; then
        echo -e "${GREEN}✓ Certificate exists for ${DOMAIN}${NC}"
        echo "  Certificate files:"
        ls -la certbot/conf/live/${DOMAIN}/ 2>/dev/null | grep -E "cert.pem|privkey.pem"
    else
        echo -e "${YELLOW}⚠ No certificate yet${NC}"
    fi
else
    echo -e "${YELLOW}⚠ certbot/conf not found (will be created)${NC}"
fi

if [ -d "certbot/www" ]; then
    echo -e "${GREEN}✓ certbot/www exists${NC}"
else
    echo -e "${YELLOW}⚠ certbot/www not found${NC}"
    mkdir -p certbot/www
    echo "  Created certbot/www"
fi
echo ""

# 7. Check webroot
echo -e "${YELLOW}[7/7] Testing Let's Encrypt webroot...${NC}"
echo "test" > certbot/www/test.txt
if curl -s http://localhost/.well-known/acme-challenge/test.txt | grep -q "test"; then
    echo -e "${GREEN}✓ Webroot is accessible${NC}"
    rm certbot/www/test.txt
else
    echo -e "${RED}✗ Webroot not accessible${NC}"
    echo "  This will cause SSL validation to fail"
fi
echo ""

# Summary
echo "========================================="
echo "  Summary"
echo "========================================="
echo ""

ALL_GOOD=true

if [ "$DNS_IP" != "$SERVER_IP" ]; then
    echo -e "${RED}✗ DNS not pointing to server${NC}"
    echo "  Action: Update DNS A record"
    ALL_GOOD=false
fi

if ! docker compose -f docker-compose.prod.yml ps 2>/dev/null | grep -q "Up"; then
    echo -e "${RED}✗ Containers not running${NC}"
    echo "  Action: docker compose -f docker-compose.prod.yml up -d"
    ALL_GOOD=false
fi

if [ "$HTTP_CODE" = "000" ]; then
    echo -e "${RED}✗ Domain not accessible from internet${NC}"
    echo "  Action: Check firewall, open port 80"
    ALL_GOOD=false
fi

if $ALL_GOOD; then
    echo -e "${GREEN}✓ Everything looks good!${NC}"
    echo ""
    echo "You can try SSL setup again:"
    echo "  ./setup-ssl.sh"
else
    echo ""
    echo "Fix the issues above, then run:"
    echo "  ./setup-ssl.sh"
fi

echo ""
