#!/bin/bash

# Setup SSL Certificate (run this on the server)
# Use this if SSL setup was skipped during deployment

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  Setup SSL Certificate"
echo "========================================="
echo ""

DOMAIN="air.arraystory.com"

echo "This will obtain SSL certificate for: $DOMAIN"
echo ""

# Ask for email
read -p "Enter your email for certificate notifications: " SSL_EMAIL

if [ -z "$SSL_EMAIL" ]; then
    echo "Error: Email required"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "docker-compose.prod.yml" ]; then
    echo "Error: Must be run from ~/air directory"
    exit 1
fi

# Request certificate
echo ""
echo "Obtaining SSL certificate..."
docker compose -f docker-compose.prod.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    -d $DOMAIN \
    --email "$SSL_EMAIL" \
    --agree-tos \
    --no-eff-email

# Reload nginx
echo "Reloading Nginx..."
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

echo ""
echo -e "${GREEN}✓ SSL certificate installed!${NC}"
echo ""
echo "Visit: https://$DOMAIN"
echo ""
