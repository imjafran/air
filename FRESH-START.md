# Fresh Start - Clean VPS Deployment

Your MySQL installation is broken. Here are your options:

## Option 1: Clean and Reinstall (Recommended)

### Step 1: Clean your VPS

```bash
# SSH into your VPS
ssh ubuntu@your-server-ip

# Download and run cleanup
cd ~
wget https://raw.githubusercontent.com/your-repo/air/main/CLEAN-VPS.sh
chmod +x CLEAN-VPS.sh
./CLEAN-VPS.sh
```

### Step 2: Fresh deployment

```bash
# On your local machine
./deploy.sh your-server-ip
```

That's it! The deploy script will handle everything.

---

## Option 2: Nuclear Fix (Try to Fix Current State)

Only if you want to keep other data on the VPS:

```bash
# SSH into VPS
ssh ubuntu@your-server-ip
cd ~/air

# Run nuclear fix
chmod +x NUCLEAR-FIX.sh
./NUCLEAR-FIX.sh

# If successful, continue
./setup.sh
```

---

## Option 3: Rebuild VPS from Provider (Fastest)

**Most reliable option:**

1. Go to your VPS provider dashboard (AWS Lightsail, DigitalOcean, etc.)
2. Rebuild/recreate your VPS with fresh Ubuntu 24.04
3. Deploy:
   ```bash
   ./deploy.sh your-new-server-ip
   ```

---

## Option 4: Manual Fresh Install

If automatic scripts don't work:

### 1. Clean current state

```bash
# On VPS
sudo apt remove --purge mysql-* -y
sudo rm -rf /var/lib/mysql /etc/mysql
sudo apt autoremove -y
sudo apt update
```

### 2. Check resources

```bash
free -h    # Should show 1GB+ RAM
df -h      # Should have 5GB+ free
```

### 3. Create swap if low memory

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 4. Install MySQL manually

```bash
# Create minimal config first
sudo mkdir -p /etc/mysql/mysql.conf.d
sudo tee /etc/mysql/mysql.conf.d/minimal.cnf > /dev/null << 'EOF'
[mysqld]
performance_schema=OFF
innodb_buffer_pool_size=64M
max_connections=25
EOF

# Install
sudo apt install -y mysql-server

# Start
sudo systemctl start mysql
```

### 5. Set password

```bash
sudo mysql

# Inside MySQL:
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your_password';
FLUSH PRIVILEGES;
exit
```

### 6. Run Air setup

```bash
cd ~/air
./setup.sh
```

---

## Troubleshooting

### MySQL still won't start

**Check error log:**
```bash
sudo tail -50 /var/log/mysql/error.log
```

**Common issues:**

1. **Out of memory** - Upgrade to 1GB+ RAM
2. **Out of disk** - Free up space or upgrade
3. **Port conflict** - Something else on port 3306

### Low memory server

For 512MB servers:
- Enable swap (see above)
- Consider using external database
- Or upgrade to 1GB+ RAM

---

## Recommended VPS Specs

**Minimum:**
- 1GB RAM
- 25GB SSD
- Ubuntu 24.04 LTS

**Recommended:**
- 2GB RAM
- 50GB SSD
- Ubuntu 24.04 LTS

**Cost:** ~$5-10/month

**Providers:**
- DigitalOcean ($6/month)
- AWS Lightsail ($5/month)
- Vultr ($6/month)
- Linode ($5/month)

---

## Quick Commands Reference

```bash
# Check VPS specs
free -h && df -h

# Clean VPS completely
./CLEAN-VPS.sh

# Fresh deployment
./deploy.sh your-server-ip

# Check if everything is running
./check-health.sh

# View Air logs
sudo journalctl -u air -f

# Restart Air
sudo systemctl restart air
```
