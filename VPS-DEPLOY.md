# Quick VPS Deployment

## One-Command Deploy

```bash
git pull && docker compose -f docker-compose.cloudflare.yml down && docker compose -f docker-compose.cloudflare.yml build --no-cache && docker compose -f docker-compose.cloudflare.yml up -d && sleep 15 && docker compose -f docker-compose.cloudflare.yml restart go-app
```

## Or Step-by-Step

```bash
# 1. Pull changes
git pull

# 2. Rebuild and restart
docker compose -f docker-compose.cloudflare.yml down
docker compose -f docker-compose.cloudflare.yml build --no-cache
docker compose -f docker-compose.cloudflare.yml up -d

# 3. Wait for MySQL
sleep 15

# 4. Restart Go app
docker compose -f docker-compose.cloudflare.yml restart go-app
```

## Verify

```bash
# Check status
docker compose -f docker-compose.cloudflare.yml ps

# Check logs
docker compose -f docker-compose.cloudflare.yml logs -f go-app
```

## Test
Visit: https://air.arraystory.com
