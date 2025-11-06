# AirSocket Production Deployment Guide

## Quick Deploy (From VPS)

```bash
git pull origin main
chmod +x deploy.sh
./deploy.sh
```

## Production URLs
- WebSocket: https://air.arraystory.com
- Demo: https://air.arraystory.com/
- Library: https://air.arraystory.com/air.js
- DB Admin: http://13.232.180.232:8283

## Deployment Steps

```bash
cd ~/realtime
git pull origin main
docker compose -f docker-compose.cloudflare.yml down
docker compose -f docker-compose.cloudflare.yml build --no-cache
docker compose -f docker-compose.cloudflare.yml up -d
sleep 15
docker compose -f docker-compose.cloudflare.yml restart go-app
docker compose -f docker-compose.cloudflare.yml ps
```

## Testing

1. Visit https://air.arraystory.com
2. Enter name and join chat
3. Test: message, image upload, file upload, typing
4. Open another device to test multi-user

## Troubleshooting

**Go app database error:**
```bash
sleep 15 && docker compose -f docker-compose.cloudflare.yml restart go-app
```

**WebSocket not connecting:**
Check domain whitelist and room exists in database.

## Logs
```bash
docker compose -f docker-compose.cloudflare.yml logs -f go-app
```
