#!/bin/bash

# AirSocket Production Deployment Script
# Usage: ./deploy.sh

set -e

echo "🚀 Deploying AirSocket to Production..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "Please create .env file from .env.example"
    exit 1
fi

# Stop existing containers
echo "📦 Stopping existing containers..."
docker compose -f docker-compose.cloudflare.yml down

# Build new images
echo "🔨 Building new images..."
docker compose -f docker-compose.cloudflare.yml build --no-cache

# Start containers
echo "🚀 Starting containers..."
docker compose -f docker-compose.cloudflare.yml up -d

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL to be ready..."
sleep 15

# Restart Go app to ensure database connection
echo "🔄 Restarting Go app..."
docker compose -f docker-compose.cloudflare.yml restart go-app

# Show status
echo "✅ Deployment complete!"
echo ""
echo "📊 Container Status:"
docker compose -f docker-compose.cloudflare.yml ps

echo ""
echo "📝 View logs:"
echo "  docker compose -f docker-compose.cloudflare.yml logs -f"
echo ""
echo "🌐 Your app is running at:"
echo "  https://air.arraystory.com"
echo "  Database Admin: http://13.232.180.232:8283"
