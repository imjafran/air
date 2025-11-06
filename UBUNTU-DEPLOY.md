# Air Deployment Guide - Ubuntu 24.04 VPS

## Server Requirements

- **OS**: Ubuntu 24.04 LTS (also compatible with 22.04, 20.04)
- **RAM**: 1GB minimum (2GB recommended)
- **Disk**: 10GB minimum
- **Network**: Public IP with ports 80, 443, and 8181 accessible

## Quick Deployment

### 1. From Your Local Machine

```bash
./deploy.sh your-server-ip-or-domain
```

The script will:
- Package and upload all files to the server
- Run `setup.sh` for first-time installation
- Run `update.sh` for subsequent deployments

### 2. On The Server (Manual Setup)

If you prefer manual deployment or the deploy script fails:

```bash
# SSH into your server
ssh ubuntu@your-server-ip

# Clone or upload your code
cd ~
mkdir -p air
cd air
# ... upload/extract your files here

# Run setup
chmod +x setup.sh
./setup.sh
```

## During Setup

You'll be prompted for:

1. **MySQL root password**: Choose a strong password (will be used for MySQL admin)
2. **MySQL air_user password**: Choose another strong password (will be used by the app)

The script will:
- Install Go, MySQL, Nginx, and Certbot
- Optimize MySQL for low-memory servers (512MB-1GB RAM)
- Create database and tables
- Build the Go application
- Set up systemd service for auto-restart
- Configure Nginx as reverse proxy

## Handling MySQL on Pre-configured Servers

If your VPS already has MySQL installed:

1. The script will detect existing MySQL
2. You'll need to provide the existing root password
3. It will create the air database and user

If MySQL installation fails or is stuck:

```bash
# Use the recovery script
chmod +x fix-mysql.sh
./fix-mysql.sh
```

## After Installation

### Check Service Status

```bash
sudo systemctl status air
```

### View Logs

```bash
sudo journalctl -u air -f
```

### Test The Application

```bash
curl http://localhost:8181/
```

## Setting Up SSL (HTTPS)

After deployment, set up SSL certificate:

```bash
sudo certbot --nginx -d your-domain.com --email your-email@example.com
```

**Requirements**:
- Domain DNS must point to your server IP (A record)
- Ports 80 and 443 must be open

## Configuration Files

### Environment Variables (.env)

Located at: `~/air/.env`

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=air_user
DB_PASSWORD=your_password_here
DB_NAME=air_production
AIR_PORT=8181
```

### Systemd Service

Located at: `/etc/systemd/system/air.service`

To restart after changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart air
```

### Nginx Configuration

Located at: `/etc/nginx/sites-available/air`

To reload after changes:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Database Management

### Access MySQL

```bash
mysql -u root -p
# or
mysql -u air_user -p air_production
```

### Backup Database

```bash
mysqldump -u root -p air_production > backup.sql
```

### Restore Database

```bash
mysql -u root -p air_production < backup.sql
```

## Updating Your Application

### Method 1: Using deploy.sh (from local machine)

```bash
./deploy.sh your-server-ip-or-domain
```

### Method 2: Git pull (on server)

```bash
cd ~/air
git pull
./update.sh
```

### Method 3: Manual update (on server)

```bash
cd ~/air
# ... update your files
go build -o air main.go
sudo systemctl restart air
```

## Troubleshooting

### MySQL Issues

**Problem**: MySQL won't start or fails to install

```bash
# Check memory
free -h

# Check logs
sudo journalctl -u mysql -n 50

# Try recovery script
./fix-mysql.sh
```

**Problem**: Access denied for root

```bash
# Reset password using recovery script
./fix-mysql.sh
```

### Service Issues

**Problem**: Air service won't start

```bash
# Check logs
sudo journalctl -u air -n 50

# Check if port is in use
sudo lsof -i :8181

# Test manually
cd ~/air
./air
```

**Problem**: WebSocket connection fails

- Check if port 8181 is open in firewall
- Verify Nginx configuration
- Check if domain is whitelisted in database

### Nginx Issues

**Problem**: 502 Bad Gateway

```bash
# Check if air service is running
sudo systemctl status air

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

## Security Best Practices

1. **Change default passwords** immediately after setup
2. **Enable firewall**:
   ```bash
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```
3. **Keep system updated**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
4. **Use SSL/TLS** for production
5. **Restrict MySQL** to localhost only
6. **Regular backups** of database and .env file

## Performance Tuning

### For Servers with Limited RAM (512MB-1GB)

The setup script automatically configures MySQL for low memory. If you need further optimization:

Edit `/etc/mysql/mysql.conf.d/low-memory.cnf`:

```ini
[mysqld]
performance_schema = OFF
innodb_buffer_pool_size = 64M
max_connections = 25
```

Then restart MySQL:

```bash
sudo systemctl restart mysql
```

### For Production Servers (2GB+ RAM)

Edit the MySQL config to increase resources:

```ini
[mysqld]
innodb_buffer_pool_size = 256M
max_connections = 100
```

## API Access

### Add API Token

```bash
mysql -u root -p air_production

INSERT INTO air_api_tokens (token, room_id, name, is_active)
VALUES ('your-secure-token-here', 1, 'My App Token', TRUE);
```

### Add Allowed Domain

```bash
mysql -u root -p air_production

INSERT INTO air_room_domains (room_id, domain)
VALUES (1, 'yourdomain.com');
```

## Monitoring

### Check Service Health

```bash
# Service status
sudo systemctl is-active air

# Resource usage
top -p $(pgrep air)

# Network connections
sudo netstat -tulpn | grep :8181
```

### Log Monitoring

```bash
# Real-time logs
sudo journalctl -u air -f

# Last 100 lines
sudo journalctl -u air -n 100

# Today's logs
sudo journalctl -u air --since today
```

## Support

If you encounter issues not covered here:

1. Check logs: `sudo journalctl -u air -n 100`
2. Check MySQL logs: `sudo journalctl -u mysql -n 100`
3. Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`
4. Verify disk space: `df -h`
5. Check memory: `free -h`
