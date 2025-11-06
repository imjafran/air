# Docker Deployment Guide

Simple, reliable deployment using Docker. No MySQL installation headaches!

## Prerequisites

- Ubuntu VPS (512MB+ RAM, 10GB+ disk)
- SSH access
- Domain pointed to your server (optional, can use IP)

## Quick Deploy (One Command)

```bash
./deploy-docker.sh your-server-ip-or-domain
```

That's it! The script will:
- Install Docker if needed
- Upload all files
- Create environment with random passwords
- Start all services
- Set up database

---

## Manual Deployment

If you prefer step-by-step:

### 1. Clean Your VPS (if needed)

```bash
# SSH into server
ssh ubuntu@your-server-ip

# Remove old installation
cd ~/air
docker compose down 2>/dev/null || true
cd ~
rm -rf air
```

### 2. Install Docker

```bash
# Update system
sudo apt update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install -y docker-compose-plugin

# Log out and back in for permissions
exit
```

### 3. Upload Files

```bash
# From your local machine
scp -r * ubuntu@your-server-ip:~/air/
```

### 4. Configure

```bash
# SSH back in
ssh ubuntu@your-server-ip
cd ~/air

# Create .env file
nano .env
```

Add:
```env
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_DATABASE=air_production
MYSQL_USER=air_user
MYSQL_PASSWORD=your_secure_password
```

### 5. Start Services

```bash
# For development (with Adminer)
docker compose up -d

# For production (with Nginx + SSL)
docker compose -f docker-compose.prod.yml up -d
```

### 6. Check Status

```bash
docker compose ps
```

You should see:
- `air_mysql` - running
- `air_go` - running
- `air_nginx` - running (prod only)
- `air_adminer` - running (dev only)

---

## Configuration

### Development Setup (docker-compose.yml)

Services:
- **MySQL**: Port 3306
- **Air App**: Port 8282 → 8181
- **Adminer**: Port 8283 (Database UI)

Access:
- App: `http://localhost:8282`
- Adminer: `http://localhost:8283`

### Production Setup (docker-compose.prod.yml)

Services:
- **MySQL**: Internal only
- **Air App**: Internal only
- **Nginx**: Ports 80, 443
- **Certbot**: SSL certificates

Access:
- App: `http://your-domain.com`
- HTTPS (after SSL): `https://your-domain.com`

---

## Database Management

### Access Database via Adminer

Development only:
1. Open `http://your-server-ip:8283`
2. Login:
   - **System**: MySQL
   - **Server**: mysql
   - **Username**: air_user
   - **Password**: (from .env)
   - **Database**: air_production

### Access Database via CLI

```bash
# Enter MySQL container
docker compose exec mysql mysql -u air_user -p

# Or as root
docker compose exec mysql mysql -u root -p
```

### Backup Database

```bash
docker compose exec mysql mysqldump -u root -p air_production > backup.sql
```

### Restore Database

```bash
docker compose exec -T mysql mysql -u root -p air_production < backup.sql
```

---

## SSL Setup (Production)

### Using Certbot (Automatic)

```bash
# Replace with your domain and email
docker compose -f docker-compose.prod.yml run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  -d your-domain.com \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email

# Reload Nginx
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

Certificates will auto-renew every 12 hours.

---

## Management Commands

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f go-app
docker compose logs -f mysql
docker compose logs -f nginx
```

### Restart Services

```bash
# All services
docker compose restart

# Specific service
docker compose restart go-app
```

### Stop Services

```bash
docker compose down
```

### Update Application

```bash
# Pull changes
cd ~/air
git pull

# Rebuild and restart
docker compose down
docker compose up -d --build
```

### Check Resource Usage

```bash
docker stats
```

---

## Troubleshooting

### Services won't start

```bash
# Check logs
docker compose logs

# Check if ports are in use
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :3306
```

### MySQL connection fails

```bash
# Check MySQL is running
docker compose ps

# Check MySQL logs
docker compose logs mysql

# Wait for MySQL to be fully ready (30 seconds after start)
sleep 30
```

### Can't connect to application

```bash
# Check if Air app is running
docker compose logs go-app

# Test internal connection
docker compose exec go-app wget -qO- http://localhost:8181
```

### Out of disk space

```bash
# Clean up old images
docker system prune -a

# Check disk usage
df -h
```

### Out of memory

```bash
# Check memory
free -h

# Restart services
docker compose restart
```

---

## Security Best Practices

1. **Change default passwords** in .env
2. **Close unused ports**:
   ```bash
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```
3. **Don't expose MySQL** port (3306) publicly
4. **Use SSL** in production
5. **Regular backups**:
   ```bash
   # Add to crontab
   0 2 * * * cd ~/air && docker compose exec mysql mysqldump -u root -pYOUR_PASSWORD air_production > ~/backups/air_$(date +\%Y\%m\%d).sql
   ```

---

## Monitoring

### Health Check Script

Create `health-check.sh`:

```bash
#!/bin/bash

echo "Air Health Check"
echo "================"
echo ""

echo "Docker Services:"
docker compose ps

echo ""
echo "Database Connection:"
docker compose exec -T mysql mysqladmin ping -h localhost --silent && echo "✅ MySQL OK" || echo "❌ MySQL DOWN"

echo ""
echo "Air App:"
docker compose exec -T go-app wget -qO- http://localhost:8181 > /dev/null 2>&1 && echo "✅ Air OK" || echo "❌ Air DOWN"

echo ""
echo "Resource Usage:"
docker stats --no-stream
```

Run: `chmod +x health-check.sh && ./health-check.sh`

---

## Comparison: Docker vs Direct Install

| Feature | Docker | Direct Install |
|---------|--------|----------------|
| Setup Time | 5 minutes | 20-30 minutes |
| Complexity | Simple | Complex |
| MySQL Issues | None | Many |
| Isolation | Full | Partial |
| Updates | Easy | Medium |
| Resource Usage | +100MB | Less |
| Best For | Most users | Special cases |

**Recommendation**: Use Docker unless you have specific reasons not to.

---

## Quick Reference

```bash
# Deploy
./deploy-docker.sh your-server-ip

# Start
docker compose up -d

# Stop
docker compose down

# Logs
docker compose logs -f

# Restart
docker compose restart

# Update
docker compose down && git pull && docker compose up -d --build

# Backup
docker compose exec mysql mysqldump -u root -p air_production > backup.sql

# Health check
docker compose ps && docker compose logs --tail=20
```

---

## Support

Common issues:
1. **Permission denied** - Log out and back in after Docker install
2. **Port in use** - Stop conflicting services
3. **MySQL slow** - Wait 30 seconds for full startup
4. **Out of memory** - Upgrade to 1GB+ RAM

For help, check logs: `docker compose logs`
