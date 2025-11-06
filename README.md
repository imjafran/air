# Air - Real-time WebSocket Server

Simple, fast real-time communication server with WebSocket support.

## Quick Deploy to AWS Lightsail

### Via Git (Recommended)

**On Local:**
```bash
git push origin main
```

**On VPS:**
```bash
cd ~/air
git pull
./setup-vps.sh
```

📖 **[Git Deployment Guide](DEPLOY-GIT.md)** | **[Quick Reference](QUICKSTART.md)**

---

## Local Development

### Using Docker (Recommended)

```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down
```

Access:
- App: http://localhost:8282
- Adminer: http://localhost:8283

### Using Go Directly

```bash
# Install dependencies
go mod download

# Run
go run main.go
```

---

## Client Usage

```html
<script src="/air.js"></script>
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

---

## Features

- ✅ WebSocket real-time messaging
- ✅ HTTP API for server-to-client
- ✅ Multi-room support
- ✅ Domain whitelisting
- ✅ API token authentication
- ✅ MySQL backed
- ✅ Docker-ready
- ✅ SSL/HTTPS support
- ✅ Auto-scaling ready

---

## Documentation

- **[Git Deployment](DEPLOY-GIT.md)** - Deploy via Git (Recommended)
- **[Quick Start](QUICKSTART.md)** - Quick reference
- **[Automated Deploy](DEPLOY.md)** - Alternative: One-command deploy
- **VPS Setup** - `./setup-vps.sh`

---

## Project Structure

```
air/
├── main.go                    # Go WebSocket server
├── schema.sql                 # Database schema
├── public/                    # Client files
│   ├── air.js                # Client library
│   └── index.html            # Demo page
├── docker-compose.yml         # Local development
├── docker-compose.prod.yml    # Production
├── Dockerfile                 # Docker image
├── nginx.conf                 # Nginx config
├── setup-vps.sh               # VPS setup script ⭐
├── setup-ssl.sh               # SSL setup
└── DEPLOY-GIT.md              # Deployment guide
