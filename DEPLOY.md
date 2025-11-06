# Deploy Air to AWS Lightsail

Simple guide to deploy Air to your AWS Lightsail server with SSL/HTTPS.

## Prerequisites

- **AWS Lightsail instance** running Ubuntu (2GB+ RAM recommended)
- **Domain name**: air.arraystory.com
- **SSH access** to your server
- **Local machine**: Mac/Linux with SSH

## Quick Start (3 Commands)

```bash
# 1. Check everything is ready
./pre-deploy-check.sh YOUR_SERVER_IP

# 2. Deploy
./deploy-lightsail.sh YOUR_SERVER_IP

# 3. Visit your site
open https://air.arraystory.com
```

That's it! 🎉

---

## Step-by-Step Guide

### Step 1: Set Up AWS Lightsail

1. **Create Instance:**
   - Go to https://lightsail.aws.amazon.com
   - Click "Create instance"
   - Choose "Linux/Unix"
   - Choose "Ubuntu 24.04 LTS" or "Ubuntu 22.04 LTS"
   - Choose plan: **$10/month (2GB RAM)** recommended
   - Name it: `air-production`
   - Click "Create instance"

2. **Configure Networking:**
   - Click on your instance
   - Go to "Networking" tab
   - Under "Firewall", add these rules:
     - HTTP: TCP 80
     - HTTPS: TCP 443
   - Note your "Public IP" (e.g., 54.123.45.67)

3. **Set Up SSH:**
   - Download SSH key from Lightsail console
   - Save it to `~/.ssh/lightsail-key.pem`
   - Set permissions:
     ```bash
     chmod 400 ~/.ssh/lightsail-key.pem
     ```
   - Add to SSH config:
     ```bash
     nano ~/.ssh/config
     ```
     Add:
     ```
     Host air-prod
       HostName YOUR_SERVER_IP
       User ubuntu
       IdentityFile ~/.ssh/lightsail-key.pem
     ```

### Step 2: Configure DNS

Point your domain to your Lightsail server:

1. Go to your domain registrar (e.g., GoDaddy, Namecheap, Route 53)
2. Add/Update DNS A record:
   - **Type**: A
   - **Name**: air (or @ for root domain)
   - **Value**: Your Lightsail IP (e.g., 54.123.45.67)
   - **TTL**: 300 (5 minutes)

3. Wait 5-10 minutes for DNS to propagate

4. Verify DNS:
   ```bash
   dig air.arraystory.com
   # Should show your server IP
   ```

### Step 3: Pre-Deployment Check

Run the check script to verify everything:

```bash
./pre-deploy-check.sh YOUR_SERVER_IP
```

This checks:
- ✓ DNS is pointing to your server
- ✓ SSH connection works
- ✓ Server has enough resources
- ✓ Ports 80 and 443 are open
- ✓ All required files exist

**If all checks pass**, proceed to deployment.

**If checks fail**, fix the issues shown before deploying.

### Step 4: Deploy

Run the deployment script:

```bash
./deploy-lightsail.sh YOUR_SERVER_IP
```

The script will:
1. Package your application
2. Upload to server
3. Install Docker (if needed)
4. Generate secure passwords
5. Start all services (MySQL, Nginx, Air app)
6. Initialize database
7. Obtain SSL certificate from Let's Encrypt
8. Configure automatic SSL renewal

**You'll be asked for:**
- Confirmation to proceed
- Email address for SSL certificate notifications

**Duration:** 3-5 minutes

### Step 5: Verify Deployment

After deployment completes:

1. **Visit your site:**
   ```
   https://air.arraystory.com
   ```
   You should see the Air demo page.

2. **Check SSL:**
   - Look for the padlock icon in your browser
   - Certificate should be valid and issued by Let's Encrypt

3. **Save your API token:**
   - The deployment script will display an API token
   - Save it somewhere safe (password manager)
   - You'll need this to send messages via HTTP API

---

## What Was Installed

On your Lightsail server:

```
~/air/
├── .env                          # Secure passwords (generated)
├── api-token.txt                 # Your API token
├── docker-compose.prod.yml       # Docker configuration
├── nginx.conf                    # Nginx configuration
├── schema.sql                    # Database schema
├── main.go                       # Air server
├── public/                       # Static files
│   ├── air.js                   # Client library
│   └── index.html               # Demo page
├── certbot/                      # SSL certificates
└── mysql/                        # Database data
```

**Docker Containers Running:**
- `air_mysql` - MySQL database
- `air_go` - Air WebSocket server
- `air_nginx` - Nginx web server
- `air_certbot` - SSL certificate manager

---

## Managing Your Deployment

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

### Update Application

```bash
# On your local machine
./deploy-lightsail.sh YOUR_SERVER_IP

# This will:
# - Upload new code
# - Rebuild containers
# - Restart services
# - Keep existing database and SSL certificates
```

### Access Database

```bash
# Get database password
cat ~/air/.env

# Access MySQL
docker compose -f docker-compose.prod.yml exec mysql mysql -u air_user -p
```

---

## Testing Your Deployment

### Test WebSocket Connection

Open browser console on https://air.arraystory.com:

```javascript
const air = new Air('demo');
air.onConnect(() => console.log('Connected!'));
air.onMessage((data) => console.log('Received:', data));
air.connect();
air.send({ test: 'Hello from browser' });
```

### Test HTTP API

```bash
# Use your API token from deployment
curl -X POST https://air.arraystory.com/emit \
  -H "Authorization: YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from API!"}'
```

---

## Troubleshooting

### Deployment Failed

**Check SSH connection:**
```bash
ssh ubuntu@YOUR_SERVER_IP
```

**Check server resources:**
```bash
free -h  # Check memory
df -h    # Check disk
```

### Can't Access Website

**Check if containers are running:**
```bash
ssh ubuntu@YOUR_SERVER_IP
cd ~/air
docker compose -f docker-compose.prod.yml ps
```

**Check nginx logs:**
```bash
docker compose -f docker-compose.prod.yml logs nginx
```

### SSL Certificate Failed

**Verify DNS first:**
```bash
dig air.arraystory.com
# Must show your server IP
```

**Manually obtain certificate:**
```bash
ssh ubuntu@YOUR_SERVER_IP
cd ~/air
docker compose -f docker-compose.prod.yml run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  -d air.arraystory.com \
  --email your-email@example.com \
  --agree-tos
```

### WebSocket Connection Fails

**Check if domain is whitelisted:**
```bash
ssh ubuntu@YOUR_SERVER_IP
cd ~/air
docker compose -f docker-compose.prod.yml exec mysql mysql -u air_user -p

# In MySQL:
USE air_production;
SELECT * FROM air_room_domains;

# Should show air.arraystory.com
# If not, add it:
INSERT INTO air_room_domains (room_id, domain) VALUES (1, 'air.arraystory.com');
```

---

## Security Best Practices

1. **Keep passwords secure:**
   - Database passwords are in `~/air/.env`
   - API token is in `~/air/api-token.txt`
   - Never commit these to git

2. **Regular updates:**
   ```bash
   ssh ubuntu@YOUR_SERVER_IP
   sudo apt update && sudo apt upgrade -y
   ```

3. **Backup database:**
   ```bash
   ssh ubuntu@YOUR_SERVER_IP
   cd ~/air
   docker compose -f docker-compose.prod.yml exec mysql mysqldump -u root -p air_production > backup.sql
   ```

4. **Monitor logs:**
   ```bash
   docker compose -f docker-compose.prod.yml logs -f --tail=100
   ```

5. **Firewall:**
   - Only ports 22 (SSH), 80 (HTTP), 443 (HTTPS) should be open
   - Check in Lightsail console → Networking

---

## Costs

**AWS Lightsail:** $10/month (2GB RAM, 60GB SSD, 3TB transfer)

**Domain:** $10-15/year (varies by registrar)

**SSL Certificate:** FREE (Let's Encrypt)

**Total:** ~$10-11/month

---

## Next Steps

- Add more API tokens for different applications
- Set up monitoring (e.g., UptimeRobot)
- Configure backups (e.g., AWS Backup)
- Add more rooms for different use cases
- Scale to multiple servers with load balancer

---

## Support

**If you get stuck:**

1. Run diagnostics:
   ```bash
   ./pre-deploy-check.sh YOUR_SERVER_IP
   ```

2. Check logs:
   ```bash
   ssh ubuntu@YOUR_SERVER_IP
   cd ~/air
   docker compose -f docker-compose.prod.yml logs --tail=50
   ```

3. Verify all services:
   ```bash
   docker compose -f docker-compose.prod.yml ps
   ```

**Common issues are usually:**
- DNS not propagated yet (wait 10-30 minutes)
- Firewall ports not open (check Lightsail console)
- SSH key issues (verify SSH config)
