# Quick Update Guide

Use this when you've pushed changes to Git and want to update the production server.

## Update Steps

1. **Push your changes to Git** (on local machine)
   ```bash
   git add .
   git commit -m "Your commit message"
   git push
   ```

2. **SSH into server**
   ```bash
   ssh ubuntu@air.arraystory.com
   ```

3. **Pull and rebuild**
   ```bash
   cd ~
   git pull
   docker compose -f docker-compose.prod.yml up -d --build
   ```

4. **Check logs**
   ```bash
   docker compose -f docker-compose.prod.yml logs -f go-app
   ```

## Quick Restart (No Code Changes)

If you only need to restart without rebuilding:
```bash
docker compose -f docker-compose.prod.yml restart go-app
```

## Full Restart (All Services)

```bash
docker compose -f docker-compose.prod.yml restart
```

## Check Status

```bash
docker compose -f docker-compose.prod.yml ps
docker logs air_go
docker logs air_nginx
docker logs air_mysql
```
