# Air - One-Command Installation

Deploy Air to your server with a single script.

## Prerequisites

1. **Ubuntu 22.04 LTS** server (AWS Lightsail, DigitalOcean, etc.)
2. **Domain** pointed to your server (A record)
3. **Firewall** open on ports 80 and 443

## Installation

### Step 1: Clone Repository

```bash
ssh ubuntu@air.arraystory.com
cd ~
git clone https://github.com/yourusername/air.git
cd air
```

### Step 2: Run Setup Script

```bash
./setup.sh
```

The script will prompt you for:
- Domain name (e.g., `air.arraystory.com`)
- MySQL root password
- MySQL air_user password
- API token (or generate automatically)
- Email for SSL certificate
- Whether to set up SSL now

### Step 3: Done!

Visit: **https://air.arraystory.com/**

## What the Script Does

1. **Installs dependencies**:
   - Go (via snap)
   - MySQL Server
   - Nginx
   - Certbot

2. **Sets up database**:
   - Creates `air_production` database
   - Creates `air_user` with secure password
   - Loads schema
   - Inserts demo room and domain

3. **Builds application**:
   - Compiles Go binary
   - Creates systemd service
   - Starts Air service

4. **Configures web server**:
   - Sets up Nginx reverse proxy
   - Configures WebSocket support
   - Serves static files

5. **SSL certificate**:
   - Obtains Let's Encrypt certificate
   - Auto-renewal configured

## After Installation

### Check Service Status
```bash
sudo systemctl status air
```

### View Logs
```bash
sudo journalctl -u air -f
```

### Test Connection
```bash
curl https://air.arraystory.com/
```

## Updating Your Application

After pushing changes to Git:

```bash
ssh ubuntu@air.arraystory.com
cd ~/air
git pull
go build -o air main.go
sudo systemctl restart air
```

## Manual Configuration

If you need to change settings:

### Update Environment Variables
```bash
nano ~/.air/.env
sudo systemctl restart air
```

### Update Nginx Config
```bash
sudo nano /etc/nginx/sites-available/air
sudo nginx -t
sudo systemctl reload nginx
```

### Update Database
```bash
mysql -u air_user -p air_production
```

## Uninstall

To remove Air:

```bash
sudo systemctl stop air
sudo systemctl disable air
sudo rm /etc/systemd/system/air.service
sudo systemctl daemon-reload
sudo rm /etc/nginx/sites-enabled/air
sudo rm /etc/nginx/sites-available/air
sudo systemctl reload nginx
```

## Troubleshooting

### Service won't start
```bash
sudo journalctl -u air -n 50
cd ~/air
./air  # Run manually to see errors
```

### Database connection error
```bash
sudo systemctl status mysql
mysql -u air_user -p air_production
```

### Nginx errors
```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### SSL certificate issues
```bash
sudo certbot renew --dry-run
```

## Security Notes

- The script generates strong passwords and tokens
- MySQL is configured for localhost access only
- UFW firewall recommended:
  ```bash
  sudo ufw allow ssh
  sudo ufw allow http
  sudo ufw allow https
  sudo ufw enable
  ```

## Getting Help

- Check logs: `sudo journalctl -u air -f`
- Test manually: `cd ~/air && ./air`
- Verify database: `mysql -u air_user -p air_production`
