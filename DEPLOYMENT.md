# Air Deployment Guide - AWS Lightsail

Deploy Air real-time chat to AWS Lightsail at **air.arraystory.com**

## Prerequisites

- AWS Account with Lightsail access
- Domain `arraystory.com` with DNS control
- SSH key pair for server access

## Step 1: Create Lightsail Instance

1. **Go to AWS Lightsail Console**
   - Navigate to https://lightsail.aws.amazon.com/

2. **Create Instance**
   - Click "Create instance"
   - Platform: **Linux/Unix**
   - Blueprint: **OS Only** → **Ubuntu 22.04 LTS**
   - Instance plan: **$5/month** (1 GB RAM, 1 vCPU, 40 GB SSD) or higher
   - Instance name: `air-chat`
   - Click "Create instance"

3. **Configure Networking**
   - Go to instance → Networking tab
   - Click "Create static IP"
   - Name it `air-static-ip`
   - Attach to `air-chat` instance
   - **Note the IP address** (e.g., 3.123.45.67)

4. **Open Firewall Ports**
   - In Networking tab, add firewall rules:
     - HTTP: Port 80 (TCP)
     - HTTPS: Port 443 (TCP)
     - SSH: Port 22 (TCP) - already open by default

## Step 2: Configure DNS

1. **Go to your DNS provider** (Namecheap, GoDaddy, Route53, etc.)

2. **Add A Record**
   ```
   Type: A
   Host: air
   Value: [Your Lightsail Static IP]
   TTL: Automatic or 3600
   ```

3. **Wait for DNS propagation** (can take 5-60 minutes)
   ```bash
   # Test DNS resolution
   nslookup air.arraystory.com
   ```

## Step 3: Connect to Server

1. **SSH into Lightsail instance**
   ```bash
   ssh ubuntu@air.arraystory.com
   # or
   ssh ubuntu@[STATIC_IP]
   ```

2. **Update system**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Step 4: Install Docker & Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version

# Log out and back in for docker group to take effect
exit
# SSH back in
ssh ubuntu@air.arraystory.com
```

## Step 5: Deploy Application

1. **Create application directory**
   ```bash
   mkdir -p ~/air
   cd ~/air
   ```

2. **Upload files to server**

   From your local machine:
   ```bash
   # Navigate to project directory
   cd /Users/jafran/Workstation/R\&D/GO/realtime

   # Upload files using scp
   scp -r * ubuntu@air.arraystory.com:~/air/
   ```

   Or use Git:
   ```bash
   # On server
   cd ~/air
   git clone [your-repo-url] .
   ```

3. **Set up production environment**
   ```bash
   cd ~/air

   # Copy production env file
   cp .env.production .env

   # Edit with strong passwords
   nano .env
   # Change MYSQL_ROOT_PASSWORD and MYSQL_PASSWORD to strong values
   ```

## Step 6: Get SSL Certificate

1. **Initial certificate setup (nginx NOT running yet)**
   ```bash
   cd ~/air

   # Create directories
   mkdir -p certbot/conf certbot/www

   # Get certificate
   sudo docker run -it --rm \
     -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
     -v "$(pwd)/certbot/www:/var/www/certbot" \
     certbot/certbot certonly --webroot \
     --webroot-path=/var/www/certbot \
     --email your-email@example.com \
     --agree-tos \
     --no-eff-email \
     -d air.arraystory.com
   ```

   **Note:** If this fails because nginx isn't running yet, we'll use a different approach:

   ```bash
   # Alternative: Use standalone mode (requires port 80 to be free)
   sudo docker run -it --rm -p 80:80 \
     -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
     -v "$(pwd)/certbot/www:/var/www/certbot" \
     certbot/certbot certonly --standalone \
     --email your-email@example.com \
     --agree-tos \
     --no-eff-email \
     -d air.arraystory.com
   ```

## Step 7: Start Application

```bash
cd ~/air

# Build and start services
docker-compose -f docker-compose.prod.yml up -d --build

# Check logs
docker-compose -f docker-compose.prod.yml logs -f

# Check running containers
docker ps
```

You should see 4 containers running:
- `air_mysql` - Database
- `air_go` - Go WebSocket server
- `air_nginx` - Nginx reverse proxy
- `air_certbot` - SSL certificate renewal

## Step 8: Initial Database Setup

```bash
# Connect to database and create initial data
docker exec -it air_mysql mysql -u root -p

# Enter your MYSQL_ROOT_PASSWORD, then run:
USE air_production;

# Verify tables exist
SHOW TABLES;

# Add production room and domain
INSERT INTO air_rooms (name, description, is_active) VALUES
('demo', 'Production demo room', TRUE);

INSERT INTO air_room_domains (room_id, domain) VALUES
(1, 'air.arraystory.com');

# Create API token
INSERT INTO air_api_tokens (token, room_id, name, is_active) VALUES
('YOUR_SECURE_TOKEN_HERE', 1, 'Production API Token', TRUE);

# Exit MySQL
EXIT;
```

## Step 9: Verify Deployment

1. **Test HTTPS access**
   ```bash
   curl https://air.arraystory.com/
   ```

2. **Open in browser**
   - Visit: https://air.arraystory.com/
   - Should see the Air Chat interface
   - Enter a name and join chat
   - Open in another browser/incognito to test real-time messaging

3. **Test WebSocket connection**
   - Open browser console (F12)
   - Check for WebSocket connection to `wss://air.arraystory.com/ws`
   - Should show "Connected" status

4. **Test API endpoint**
   ```bash
   curl -X POST https://air.arraystory.com/emit \
     -H "Authorization: YOUR_SECURE_TOKEN_HERE" \
     -H "Content-Type: application/json" \
     -d '{"message":"Test from API"}'
   ```

## Step 10: Monitoring & Maintenance

### View Logs
```bash
# All services
docker-compose -f docker-compose.prod.yml logs -f

# Specific service
docker-compose -f docker-compose.prod.yml logs -f go-app
docker-compose -f docker-compose.prod.yml logs -f nginx
```

### Restart Services
```bash
docker-compose -f docker-compose.prod.yml restart
```

### Update Application
```bash
cd ~/air

# Pull latest changes (if using Git)
git pull

# Rebuild and restart
docker-compose -f docker-compose.prod.yml up -d --build
```

### Check SSL Certificate Renewal
```bash
# Certbot auto-renews every 12 hours
# Manually test renewal:
docker-compose -f docker-compose.prod.yml exec certbot certbot renew --dry-run
```

### Database Backup
```bash
# Backup database
docker exec air_mysql mysqldump -u root -p air_production > backup_$(date +%Y%m%d).sql

# Restore database
docker exec -i air_mysql mysql -u root -p air_production < backup_20231106.sql
```

## Troubleshooting

### WebSocket connection fails
- Check if nginx is running: `docker ps | grep nginx`
- Check nginx logs: `docker logs air_nginx`
- Verify SSL certificate: `sudo ls -la ~/air/certbot/conf/live/air.arraystory.com/`

### Database connection refused
- Check if MySQL is running: `docker ps | grep mysql`
- Check MySQL logs: `docker logs air_mysql`
- Verify environment variables: `cat ~/air/.env`

### 502 Bad Gateway
- Go app might not be running: `docker logs air_go`
- Restart services: `docker-compose -f docker-compose.prod.yml restart`

### SSL certificate issues
- Re-run certbot: See Step 6
- Check nginx SSL config in `nginx.conf`

## Security Recommendations

1. **Change default passwords** in `.env` file
2. **Use strong API tokens** (generate with: `openssl rand -hex 32`)
3. **Regular backups** of database and configuration
4. **Keep system updated**: `sudo apt update && sudo apt upgrade -y`
5. **Monitor logs regularly** for suspicious activity
6. **Enable Lightsail automatic snapshots** for disaster recovery

## Production URLs

- **Chat Interface**: https://air.arraystory.com/
- **API Endpoint**: https://air.arraystory.com/emit
- **WebSocket**: wss://air.arraystory.com/ws

## Done!

Your Air chat is now live at **https://air.arraystory.com/** 🚀
