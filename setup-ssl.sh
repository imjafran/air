#!/bin/bash

# Setup SSL Certificate (run this on the server)
# Use this if SSL setup was skipped during deployment

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  Setup SSL Certificate"
echo "========================================="
echo ""

DOMAIN="air.arraystory.com"

echo "This will obtain SSL certificate for: $DOMAIN"
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.prod.yml" ]; then
    echo -e "${RED}Error: Must be run from ~/air directory${NC}"
    exit 1
fi

# Check if containers are running
if ! docker compose -f docker-compose.prod.yml ps | grep -q "Up"; then
    echo -e "${RED}Error: Containers not running${NC}"
    echo "Start them first: docker compose -f docker-compose.prod.yml up -d"
    exit 1
fi

# Check DNS
echo "Checking DNS..."
DNS_IP=$(dig +short ${DOMAIN} A | tail -n1)
# Get IPv4 address specifically
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -s ifconfig.me)

echo "Domain ${DOMAIN} resolves to: ${DNS_IP}"
echo "This server IP: ${SERVER_IP}"
echo ""

if [ "$DNS_IP" != "$SERVER_IP" ]; then
    echo -e "${RED}ERROR: DNS mismatch!${NC}"
    echo "Domain does not point to this server"
    echo "Update your DNS A record to: ${SERVER_IP}"
    echo ""
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi

# Test if port 80 is accessible
echo "Testing port 80..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost/.well-known/acme-challenge/ | grep -q "404\|200"; then
    echo -e "${GREEN}✓ Nginx is serving on port 80${NC}"
else
    echo -e "${RED}✗ Cannot access port 80${NC}"
    echo "Check if nginx is running: docker compose -f docker-compose.prod.yml ps"
    exit 1
fi

# Ask for email
echo ""
read -p "Enter your email for certificate notifications: " SSL_EMAIL

if [ -z "$SSL_EMAIL" ]; then
    echo -e "${RED}Error: Email required${NC}"
    exit 1
fi

# Check if certificate already exists
if [ -d "certbot/conf/live/${DOMAIN}" ]; then
    echo ""
    echo -e "${YELLOW}Certificate already exists${NC}"
    read -p "Force renewal? (y/n): " RENEW
    if [ "$RENEW" = "y" ]; then
        CERTBOT_CMD="renew --force-renewal"
    else
        echo "Exiting. Certificate already exists."
        exit 0
    fi
else
    CERTBOT_CMD="certonly --webroot --webroot-path=/var/www/certbot -d ${DOMAIN} --email ${SSL_EMAIL} --agree-tos --no-eff-email"
fi

# Request certificate
echo ""
echo "Requesting certificate from Let's Encrypt..."
echo "This may take 1-2 minutes..."
echo ""

if docker compose -f docker-compose.prod.yml run --rm certbot $CERTBOT_CMD; then
    echo ""
    echo -e "${GREEN}✓ SSL certificate obtained!${NC}"

    # Reload nginx
    echo "Reloading Nginx..."
    docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

    echo ""
    echo -e "${GREEN}✓ SSL certificate installed!${NC}"
    echo ""
    echo "Visit: https://$DOMAIN"
    echo ""
    echo "Certificate will auto-renew every 12 hours"
    echo ""
else
    echo ""
    echo -e "${RED}✗ SSL certificate request failed${NC}"
    echo ""
    echo "Common issues:"
    echo "1. DNS not pointing to this server (check above)"
    echo "2. Ports 80/443 not open in firewall"
    echo "3. Domain not accessible from internet"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check DNS: dig ${DOMAIN}"
    echo "  • Test access: curl http://${DOMAIN}"
    echo "  • Check logs: docker compose -f docker-compose.prod.yml logs nginx"
    echo ""
    exit 1
fi
