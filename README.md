# Air - Real-time WebSocket Server

Simple, fast real-time communication for your applications.

## Quick Start

### Docker Deployment (Recommended)

**Easiest and most reliable:**

```bash
./deploy-docker.sh your-server-ip
```

See [DOCKER-DEPLOY.md](DOCKER-DEPLOY.md) for full Docker guide.

### Direct Installation

**For advanced users:**

```bash
./deploy.sh your-server-ip
```

See [UBUNTU-DEPLOY.md](UBUNTU-DEPLOY.md) for full direct installation guide.

---

## Features

- ✅ WebSocket real-time communication
- ✅ HTTP API for server-to-client messaging
- ✅ Room-based messaging
- ✅ Domain whitelisting
- ✅ API token authentication
- ✅ MySQL backed
- ✅ Go-powered performance

---

## Architecture

```
┌─────────────┐     WebSocket      ┌──────────┐
│   Browser   │◄──────────────────►│   Air    │
│   Client    │                    │  Server  │
└─────────────┘                    └────┬─────┘
                                        │
┌─────────────┐     HTTP API       ┌────▼─────┐
│   Your      │────────────────────►│  MySQL   │
│   Server    │                    │ Database │
└─────────────┘                    └──────────┘
```

---

## Local Development

### Using Docker

```bash
# Copy environment template
cp .env.docker .env

# Edit .env with your passwords
nano .env

# Start services
docker compose up -d

# Access
# App: http://localhost:8282
# Adminer: http://localhost:8283
```

### Using Go Directly

```bash
# Install dependencies
go mod download

# Set up local MySQL
mysql -u root -p < schema.sql

# Create .env
cat > .env << EOF
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=air_production
AIR_PORT=8181
EOF

# Run
go run main.go
```

---

## Client Usage

### JavaScript/Browser

```html
<script src="http://your-server/air.js"></script>
<script>
const air = new Air('room-name');

air.onConnect(() => {
    console.log('Connected!');
});

air.onMessage((data) => {
    console.log('Received:', data);
});

air.connect();

// Send message
air.send({ hello: 'world' });
</script>
```

See [CLIENT_USAGE.md](CLIENT_USAGE.md) for full API documentation.

---

## API Usage

### Emit Message via HTTP API

```bash
curl -X POST http://your-server/emit \
  -H "Authorization: your-api-token" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from server!"}'
```

### Add API Token

```sql
INSERT INTO air_api_tokens (token, room_id, name, is_active)
VALUES ('your-secure-token', 1, 'My App', TRUE);
```

### Add Allowed Domain

```sql
INSERT INTO air_room_domains (room_id, domain)
VALUES (1, 'yourdomain.com');
```

---

## Deployment Methods

### 1. Docker (Recommended) ⭐

**Pros:**
- Simple setup (5 minutes)
- No MySQL installation issues
- Isolated environment
- Easy updates

**Cons:**
- Uses ~100MB more RAM
- Requires Docker

**Best for:** Most users, production deployments

[📖 Docker Deployment Guide](DOCKER-DEPLOY.md)

### 2. Direct Installation

**Pros:**
- Lower resource usage
- Direct system access
- No Docker overhead

**Cons:**
- Complex MySQL setup
- More troubleshooting
- System dependencies

**Best for:** Experienced admins, special requirements

[📖 Direct Installation Guide](UBUNTU-DEPLOY.md)

---

## Troubleshooting

### Docker Issues

```bash
# Check logs
docker compose logs -f

# Restart services
docker compose restart

# Clean install
docker compose down -v
docker compose up -d
```

### Direct Install Issues

```bash
# Clean VPS completely
./CLEAN-VPS.sh

# Fresh deployment
./deploy.sh your-server-ip

# Check health
./check-health.sh
```

### MySQL Problems

See:
- [fix-mysql.sh](fix-mysql.sh) - Standard fix
- [fix-broken-mysql.sh](fix-broken-mysql.sh) - Aggressive fix
- [NUCLEAR-FIX.sh](NUCLEAR-FIX.sh) - Complete reset
- [diagnose-mysql.sh](diagnose-mysql.sh) - Diagnostics

---

## Management

### Docker Commands

```bash
# View logs
docker compose logs -f

# Restart
docker compose restart

# Stop
docker compose down

# Update
git pull && docker compose up -d --build

# Backup database
docker compose exec mysql mysqldump -u root -p air_production > backup.sql
```

### Direct Install Commands

```bash
# View logs
sudo journalctl -u air -f

# Restart
sudo systemctl restart air

# Status
sudo systemctl status air

# Update
cd ~/air && ./update.sh
```

---

## Configuration

### Database Schema

- `air_rooms` - Room definitions
- `air_room_domains` - Whitelisted domains per room
- `air_api_tokens` - API access tokens

### Environment Variables

```env
# MySQL (Docker)
MYSQL_ROOT_PASSWORD=root_password
MYSQL_DATABASE=air_production
MYSQL_USER=air_user
MYSQL_PASSWORD=user_password

# Air (Direct Install)
DB_HOST=localhost
DB_PORT=3306
DB_USER=air_user
DB_PASSWORD=user_password
DB_NAME=air_production
AIR_PORT=8181
```

---

## Performance

### Recommended VPS Specs

**Minimum:**
- 512MB RAM (with Docker)
- 1GB RAM (direct install)
- 10GB disk

**Production:**
- 2GB RAM
- 25GB SSD
- 2 CPU cores

**High Traffic:**
- 4GB+ RAM
- 50GB+ SSD
- 4+ CPU cores

### Optimization

For high-traffic deployments, see production configuration in:
- Docker: `docker-compose.prod.yml`
- Direct: Edit `/etc/mysql/mysql.conf.d/low-memory.cnf`

---

## Security

1. ✅ Change default passwords
2. ✅ Use SSL/TLS in production
3. ✅ Whitelist domains
4. ✅ Secure API tokens
5. ✅ Enable firewall
6. ✅ Regular backups
7. ✅ Keep system updated

---

## Project Structure

```
air/
├── main.go                    # Go server
├── schema.sql                 # Database schema
├── public/                    # Client files
│   ├── air.js                 # Client library
│   └── index.html             # Demo page
├── docker-compose.yml         # Docker dev config
├── docker-compose.prod.yml    # Docker prod config
├── Dockerfile                 # Docker image
├── deploy-docker.sh           # Docker deployment
├── deploy.sh                  # Direct deployment
├── setup.sh                   # Direct install script
├── update.sh                  # Update script
└── docs/                      # Documentation
    ├── DOCKER-DEPLOY.md
    ├── UBUNTU-DEPLOY.md
    └── CLIENT_USAGE.md
```

---

## Contributing

Pull requests welcome!

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit PR

---

## License

MIT License - see LICENSE file

---

## Support

- 📖 Documentation: See guides in this repo
- 🐛 Issues: Create GitHub issue
- 💬 Questions: Open discussion

---

## Quick Links

- [Docker Deployment Guide](DOCKER-DEPLOY.md) ⭐ Recommended
- [Direct Installation Guide](UBUNTU-DEPLOY.md)
- [Client API Documentation](CLIENT_USAGE.md)
- [Fresh Start Guide](FRESH-START.md)

---

**Choose your deployment method above and get started in 5 minutes!**
