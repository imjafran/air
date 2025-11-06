# Air - Quick Start Guide

## Deploy to AWS Lightsail (Git Workflow)

### On Local Machine

```bash
# 1. Commit and push
git add .
git commit -m "Deploy to production"
git push origin main
```

### On VPS

```bash
# 2. Pull and setup
ssh ubuntu@YOUR_SERVER_IP
cd ~/air
git pull
./setup-vps.sh

# 3. Done! Visit:
# https://air.arraystory.com
```

## Local Development

```bash
# Start
docker compose up -d

# View logs
docker compose logs -f

# Access
open http://localhost:8282
```

## Update/Redeploy

### On Local Machine

```bash
git add .
git commit -m "Update"
git push
```

### On VPS

```bash
ssh ubuntu@YOUR_SERVER_IP
cd ~/air

# Pull updates
git pull

# Rebuild and restart
docker compose -f docker-compose.prod.yml up -d --build

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Check status
docker compose -f docker-compose.prod.yml ps
```

## Client Usage

```html
<script src="https://air.arraystory.com/air.js"></script>
<script>
const air = new Air('room-name');
air.onMessage((data) => console.log(data));
air.connect();
air.send({ hello: 'world' });
</script>
```

## API Usage

```bash
curl -X POST https://air.arraystory.com/emit \
  -H "Authorization: YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello!"}'
```

## Troubleshooting

```bash
# Check deployment readiness
./pre-deploy-check.sh YOUR_SERVER_IP

# View server logs
ssh ubuntu@YOUR_SERVER_IP "cd ~/air && docker compose -f docker-compose.prod.yml logs --tail=50"

# Check if services are running
ssh ubuntu@YOUR_SERVER_IP "cd ~/air && docker compose -f docker-compose.prod.yml ps"
```

## Full Guide

See [DEPLOY.md](DEPLOY.md) for complete step-by-step instructions.
