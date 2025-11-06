# Simple Deployment (Without Docker)

Deploy Air to AWS Lightsail without Docker - direct installation.

## Quick Steps

### 1. Create Lightsail Instance
- Go to AWS Lightsail → Create instance
- Choose: **Ubuntu 22.04 LTS**
- Plan: **$5/month or higher**
- Create **static IP** and attach it
- Note the IP address

### 2. Configure DNS
Add A record:
```
Type: A
Host: air
Value: [Your Lightsail Static IP]
```

### 3. SSH and Install Dependencies
```bash
ssh ubuntu@air.arraystory.com

# Update system
sudo apt update && sudo apt upgrade -y

# Install Go
sudo snap install go --classic

# Install MySQL
sudo apt install -y mysql-server

# Install Nginx
sudo apt install -y nginx

# Install Certbot
sudo apt install -y certbot python3-certbot-nginx
```

### 4. Clone Repository
```bash
cd ~
git clone [your-repo-url] air
cd air
```

### 5. Set Up MySQL Database
```bash
# Start MySQL
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL (set root password)
sudo mysql_secure_installation

# Create database and user
sudo mysql -u root -p

# In MySQL prompt, run:
CREATE DATABASE air_production;
CREATE USER 'air_user'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON air_production.* TO 'air_user'@'localhost';
FLUSH PRIVILEGES;

# Load schema
USE air_production;
SOURCE schema.sql;

# Add demo room and domain
INSERT INTO air_rooms (name, description, is_active) VALUES ('demo', 'Production demo room', TRUE);
INSERT INTO air_room_domains (room_id, domain) VALUES (1, 'air.arraystory.com');
INSERT INTO air_api_tokens (token, room_id, name, is_active) VALUES ('your-secure-token-here', 1, 'Production API Token', TRUE);

EXIT;
```

### 6. Create Environment File
```bash
cd ~/air
nano .env
```

Add:
```
DB_HOST=localhost
DB_PORT=3306
DB_USER=air_user
DB_PASSWORD=your_secure_password
DB_NAME=air_production
AIR_PORT=8181
```

### 7. Build and Run Go Application
```bash
cd ~/air

# Build the application
go build -o air main.go

# Test run
./air
# Press Ctrl+C after verifying it starts
```

### 8. Create Systemd Service
```bash
sudo nano /etc/systemd/system/air.service
```

Add:
```ini
[Unit]
Description=Air WebSocket Server
After=network.target mysql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/air
ExecStart=/home/ubuntu/air/air
Restart=always
RestartSec=3
Environment="DB_HOST=localhost"
Environment="DB_PORT=3306"
Environment="DB_USER=air_user"
Environment="DB_PASSWORD=your_secure_password"
Environment="DB_NAME=air_production"
Environment="AIR_PORT=8181"

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable air
sudo systemctl start air
sudo systemctl status air
```

### 9. Configure Nginx
```bash
sudo nano /etc/nginx/sites-available/air
```

Add:
```nginx
server {
    listen 80;
    server_name air.arraystory.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Root path serves static files
    location / {
        root /home/ubuntu/air/public;
        try_files $uri $uri/ /index.html;
    }

    # WebSocket endpoint
    location /ws {
        proxy_pass http://localhost:8181;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    # API endpoint
    location /emit {
        proxy_pass http://localhost:8181;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Use production air.js
    location /air.js {
        alias /home/ubuntu/air/public/air.prod.js;
        add_header Content-Type application/javascript;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/air /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### 10. Get SSL Certificate
```bash
sudo certbot --nginx -d air.arraystory.com
```

Follow prompts:
- Enter email: your-email@example.com
- Agree to terms: Yes
- Redirect HTTP to HTTPS: Yes

### 11. Test
Visit: **https://air.arraystory.com/**

## Updating Your Application

After pushing changes to Git:

```bash
ssh ubuntu@air.arraystory.com
cd ~/air

# Pull latest changes
git pull

# Rebuild
go build -o air main.go

# Restart service
sudo systemctl restart air

# Check status
sudo systemctl status air

# View logs
sudo journalctl -u air -f
```

## Useful Commands

### Check Service Status
```bash
sudo systemctl status air
sudo journalctl -u air -f
```

### Check Nginx
```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

### Check MySQL
```bash
sudo systemctl status mysql
mysql -u air_user -p air_production
```

### Restart Services
```bash
sudo systemctl restart air
sudo systemctl restart nginx
```

## Troubleshooting

### Service won't start
```bash
# Check logs
sudo journalctl -u air -n 50

# Check if port is already in use
sudo netstat -tlnp | grep 8181

# Test manually
cd ~/air
./air
```

### Database connection error
```bash
# Check MySQL is running
sudo systemctl status mysql

# Test connection
mysql -u air_user -p air_production

# Check environment variables
sudo systemctl show air | grep Environment
```

### Nginx errors
```bash
# Check configuration
sudo nginx -t

# Check logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

### SSL certificate issues
```bash
# Renew certificate manually
sudo certbot renew --dry-run

# Certificate auto-renews, cron job is at:
sudo systemctl list-timers | grep certbot
```

## Performance

This setup is:
- **Lightweight** - No Docker overhead
- **Fast startup** - Native binary execution
- **Easy debugging** - Direct access to logs via journalctl
- **Simple updates** - Just git pull and restart

## Security

1. **Change database password** to something strong
2. **Use strong API tokens** (generate with: `openssl rand -hex 32`)
3. **Keep system updated**: `sudo apt update && sudo apt upgrade`
4. **Enable UFW firewall**:
   ```bash
   sudo ufw allow ssh
   sudo ufw allow http
   sudo ufw allow https
   sudo ufw enable
   ```
