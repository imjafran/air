# Deploy Air via Git (Recommended)

Simple git-based deployment for AWS Lightsail.

## Overview

1. **Local**: Push code to GitHub
2. **VPS**: Pull from GitHub and run setup
3. **Done**: App is live with SSL

---

## Prerequisites

- AWS Lightsail Ubuntu instance (2GB+ RAM)
- Domain: air.arraystory.com pointing to your VPS IP
- Git repository set up
- SSH access to VPS

---

## First Time Setup

### Step 1: Prepare Your VPS

```bash
# SSH into VPS
ssh ubuntu@YOUR_SERVER_IP

# Clone your repository
cd ~
git clone https://github.com/YOUR_USERNAME/air.git
cd air
```

### Step 2: Configure DNS

Point your domain to VPS:
- **Domain**: air.arraystory.com
- **Type**: A Record
- **Value**: Your VPS IP address
- **TTL**: 300

Verify:
```bash
dig air.arraystory.com
# Should show your VPS IP
```

### Step 3: Configure Lightsail Firewall

Open these ports:
- **22** - SSH
- **80** - HTTP
- **443** - HTTPS

(Go to Lightsail Console → Your Instance → Networking → Firewall)

### Step 4: Run Setup

```bash
# On your VPS
cd ~/air
./setup-vps.sh
```

The script will:
- ✅ Install Docker (if needed)
- ✅ Generate secure passwords
- ✅ Start all services
- ✅ Initialize database
- ✅ Optionally set up SSL

**Time**: 3-5 minutes

**When prompted for SSL:**
- Enter your email for certificate notifications
- Script will obtain free SSL from Let's Encrypt

### Step 5: Save Important Info

The script displays:
- **API Token** - Save this for your applications
- **Database Password** - Saved in `.env` file

---

## Updating Your App

### When You Make Changes

**On Local Machine:**

```bash
# Commit your changes
git add .
git commit -m "Updated feature X"
git push origin main
```

**On VPS:**

```bash
# SSH to VPS
ssh ubuntu@YOUR_SERVER_IP
cd ~/air

# Pull updates
git pull

# Rebuild and restart
docker compose -f docker-compose.prod.yml up -d --build
```

**Done!** Changes are live.

---

## Common Tasks

### View Logs

```bash
ssh ubuntu@YOUR_SERVER_IP
cd ~/air
docker compose -f docker-compose.prod.yml logs -f
```

### Check Status

```bash
docker compose -f docker-compose.prod.yml ps
```

### Restart Services

```bash
docker compose -f docker-compose.prod.yml restart
```

### Stop Services

```bash
docker compose -f docker-compose.prod.yml down
```

### Backup Database

```bash
docker compose -f docker-compose.prod.yml exec mysql mysqldump \
  -u root -p air_production > backup-$(date +%Y%m%d).sql
```

### View Database Password

```bash
cat ~/air/.env
```

### View API Token

```bash
cat ~/air/api-token.txt
```

---

## SSL Certificate

### If You Skipped SSL During Setup

Run this on VPS:

```bash
cd ~/air
./setup-ssl.sh
```

### Force SSL Renewal

```bash
docker compose -f docker-compose.prod.yml run --rm certbot renew
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

---

## Troubleshooting

### Docker Permission Denied

```bash
# On VPS, log out and back in
exit
ssh ubuntu@YOUR_SERVER_IP
cd ~/air
```

### Container Won't Start

```bash
# Check logs
docker compose -f docker-compose.prod.yml logs

# Check if ports are in use
sudo lsof -i :80
sudo lsof -i :443
```

### SSL Certificate Stuck or Failed

**If SSL request is stuck:**
1. Press Ctrl+C to cancel
2. Run diagnostics:
```bash
./troubleshoot-ssl.sh
```

**Common issues:**

1. **DNS not pointing to server**
   ```bash
   # Check DNS
   dig air.arraystory.com
   # Should match your server IP
   ```

2. **Port 80 not accessible**
   ```bash
   # Open in Lightsail firewall
   # Then test: curl http://air.arraystory.com
   ```

3. **Domain not accessible from internet**
   ```bash
   # Test from your local machine:
   curl http://air.arraystory.com
   ```

**After fixing issues, try SSL again:**
```bash
./setup-ssl.sh
```

### Database Connection Failed

```bash
# Wait for MySQL to be ready
docker compose -f docker-compose.prod.yml exec mysql mysqladmin ping

# Check MySQL logs
docker compose -f docker-compose.prod.yml logs mysql
```

### Can't Pull from Git

```bash
# Set up SSH key or use HTTPS
git remote set-url origin https://github.com/YOUR_USERNAME/air.git
```

---

## File Structure on VPS

```
~/air/
├── .env                          # Database passwords (auto-generated)
├── .git/                         # Git repository
├── api-token.txt                 # Your API token
├── docker-compose.prod.yml       # Production config
├── nginx.conf                    # Nginx config
├── main.go                       # Go server
├── schema.sql                    # Database schema
├── public/                       # Static files
├── mysql/                        # Database data (created)
├── certbot/                      # SSL certificates (created)
└── setup-vps.sh                  # Setup script
```

---

## Environment Variables

The `.env` file is auto-generated with secure random passwords:

```env
MYSQL_ROOT_PASSWORD=generated_password_here
MYSQL_DATABASE=air_production
MYSQL_USER=air_user
MYSQL_PASSWORD=generated_password_here
```

**Don't commit `.env` to git!** (Already in `.gitignore`)

---

## Security Checklist

- ✅ Firewall configured (only 22, 80, 443)
- ✅ SSL/HTTPS enabled
- ✅ Strong random passwords generated
- ✅ Database not exposed externally
- ✅ Regular updates scheduled
- ✅ Backups configured

---

## Monitoring

### Check if Services are Running

```bash
ssh ubuntu@YOUR_SERVER_IP "cd ~/air && docker compose -f docker-compose.prod.yml ps"
```

### Quick Health Check

```bash
curl https://air.arraystory.com
# Should return the demo page
```

### Test WebSocket

```bash
# From browser console on your site
const air = new Air('demo');
air.onConnect(() => console.log('Connected!'));
air.connect();
```

---

## Costs

- **Lightsail**: $10/month (2GB RAM)
- **Domain**: $10-15/year
- **SSL**: Free (Let's Encrypt)
- **Total**: ~$10-11/month

---

## Quick Reference

```bash
# First time setup
git clone YOUR_REPO ~/air
cd ~/air
./setup-vps.sh

# Update app
git pull
docker compose -f docker-compose.prod.yml up -d --build

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Restart
docker compose -f docker-compose.prod.yml restart

# Setup SSL
./setup-ssl.sh
```

---

## Support

**Logs location:**
```bash
docker compose -f docker-compose.prod.yml logs
```

**Common issues:**
1. DNS not pointing to server → Update A record
2. Ports not open → Check Lightsail firewall
3. Docker permission → Log out and back in
4. SSL failed → DNS must resolve correctly first
