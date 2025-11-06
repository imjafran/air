# Quick Deployment to AWS Lightsail

## What You Need

1. **AWS Lightsail account**
2. **Domain DNS access** (to add A record for `air.arraystory.com`)
3. **Your email** (for SSL certificate)

## Quick Steps

### 1. Create Lightsail Instance
- Go to AWS Lightsail → Create instance
- Choose: **Ubuntu 22.04 LTS**
- Plan: **$5/month or higher**
- Create **static IP** and note it down

### 2. Configure DNS
Add A record:
```
Type: A
Host: air
Value: [Your Lightsail Static IP]
```

### 3. SSH and Install Docker
```bash
ssh ubuntu@air.arraystory.com

# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Apply docker group without logging out
newgrp docker
```

### 4. Upload Files

From your local machine:
```bash
cd /Users/jafran/Workstation/R\&D/GO/realtime
./deploy.sh air.arraystory.com
```

Or manually:
```bash
scp -r * ubuntu@air.arraystory.com:~/
```

### 5. Set Up Environment
```bash
ssh ubuntu@air.arraystory.com
cd ~
cp .env.production .env
nano .env  # Change passwords!
```

### 6. Get SSL Certificate
```bash
mkdir -p certbot/conf certbot/www

sudo docker run -it --rm -p 80:80 \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  certbot/certbot certonly --standalone \
  --email YOUR_EMAIL@example.com \
  --agree-tos \
  --no-eff-email \
  -d air.arraystory.com
```

### 7. Start Services
```bash
docker compose -f docker-compose.prod.yml up -d --build
```

### 8. Set Up Database
```bash
docker exec -it air_mysql mysql -u root -p

# Then run:
USE air_production;

INSERT INTO air_rooms (name, description, is_active) VALUES
('demo', 'Production demo room', TRUE);

INSERT INTO air_room_domains (room_id, domain) VALUES
(1, 'air.arraystory.com');

INSERT INTO air_api_tokens (token, room_id, name, is_active) VALUES
('YOUR_SECURE_TOKEN', 1, 'Production Token', TRUE);

EXIT;
```

### 9. Test
Visit: **https://air.arraystory.com/**

## Files Created

- ✅ `air.prod.js` - Production WebSocket client (wss://)
- ✅ `docker-compose.prod.yml` - Production Docker setup with nginx
- ✅ `nginx.conf` - Reverse proxy with SSL and WebSocket support
- ✅ `.env.production` - Production environment template
- ✅ `deploy.sh` - Automated deployment script
- ✅ `DEPLOYMENT.md` - Complete deployment guide

## Important Security Notes

1. **Change passwords** in `.env` file
2. **Generate secure API token**: `openssl rand -hex 32`
3. **Enable Lightsail snapshots** for backups

## Need Help?

See detailed guide: **DEPLOYMENT.md**
