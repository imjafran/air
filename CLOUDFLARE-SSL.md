# SSL with Cloudflare

If you're using Cloudflare, there are two ways to set up SSL:

## Option 1: Use Cloudflare SSL (Recommended)

This is the easiest - Cloudflare provides free SSL automatically.

### Steps:

1. **In Cloudflare Dashboard:**
   - Go to SSL/TLS settings
   - Set SSL mode to **"Full (strict)"** or **"Full"**

2. **On Your VPS:**
   ```bash
   cd ~/air

   # Skip Let's Encrypt SSL (you don't need it with Cloudflare)
   ./skip-ssl.sh
   ```

3. **Access Your App:**
   - Visit: https://air.arraystory.com
   - Cloudflare automatically provides SSL
   - Your server uses HTTP, Cloudflare handles HTTPS

**How it works:**
```
Browser → [HTTPS] → Cloudflare → [HTTP] → Your Server
```

This is the standard Cloudflare setup and works perfectly!

---

## Option 2: Let's Encrypt (Advanced)

Only use this if you want Let's Encrypt certificate on your server.

### Temporary DNS Change Method:

1. **In Cloudflare Dashboard:**
   - Click the cloud icon next to air.arraystory.com
   - Change from **Proxied** (orange cloud) to **DNS only** (gray cloud)
   - Wait 2-3 minutes for DNS to propagate

2. **On Your VPS:**
   ```bash
   cd ~/air
   ./setup-ssl.sh
   ```

3. **After SSL is set up:**
   - Go back to Cloudflare
   - Turn proxy back on (orange cloud)
   - Set SSL mode to "Full (strict)"

---

## Which Option to Choose?

### Use Option 1 (Cloudflare SSL) if:
- ✅ You want the simplest setup
- ✅ You're okay with Cloudflare handling SSL
- ✅ You want free DDoS protection
- ✅ You want faster setup (no waiting)

### Use Option 2 (Let's Encrypt) if:
- You want end-to-end encryption
- You need specific certificate requirements
- You want direct control over certificates

**For most users: Option 1 (Cloudflare SSL) is recommended!**

---

## Current Setup Instructions

Since you're using Cloudflare, let's use **Option 1**:

### On Your VPS:

```bash
cd ~/air

# Skip Let's Encrypt SSL
./skip-ssl.sh

# Make sure everything is running
docker compose -f docker-compose.prod.yml ps
```

### In Cloudflare Dashboard:

1. Go to: https://dash.cloudflare.com
2. Select your domain
3. Go to **SSL/TLS** → **Overview**
4. Set SSL mode to: **Full** or **Full (strict)**
5. Done!

### Test:

Visit: https://air.arraystory.com

You should see:
- ✅ Padlock in browser (SSL working)
- ✅ Certificate from Cloudflare
- ✅ Your Air app working

---

## Cloudflare SSL Modes Explained

**Full (strict)** - Most secure
- Cloudflare ↔ Browser: HTTPS (Cloudflare cert)
- Your Server ↔ Cloudflare: HTTP is fine
- Validates origin server

**Full** - Secure enough
- Same as above but less strict validation
- Good for most setups

**Flexible** - Not recommended
- Cloudflare ↔ Browser: HTTPS
- Your Server ↔ Cloudflare: HTTP
- Less secure

Use **Full** or **Full (strict)**.

---

## Troubleshooting with Cloudflare

### "Too many redirects" error

**Fix:** Change SSL mode in Cloudflare
1. Go to SSL/TLS settings
2. Change to "Full" mode
3. Wait 30 seconds
4. Try again

### Website shows "Error 525"

**Fix:** Your server isn't responding
```bash
# Check if containers are running
docker compose -f docker-compose.prod.yml ps

# Restart if needed
docker compose -f docker-compose.prod.yml restart
```

### Website shows "Error 526"

**Fix:** SSL mode issue
- In Cloudflare: Change to "Full" mode (not "Full strict")

### Can't access website

**Fix:** Check if DNS is correct
```bash
# Should show Cloudflare IP (172.x.x.x or 104.x.x.x)
dig air.arraystory.com
```

If not showing Cloudflare IP:
- Check DNS records in Cloudflare
- Make sure proxy is ON (orange cloud)

---

## Benefits of Cloudflare SSL

- ✅ Free SSL certificate
- ✅ Auto-renewal (no management needed)
- ✅ DDoS protection
- ✅ Faster site (CDN caching)
- ✅ Automatic HTTPS redirect
- ✅ Better performance globally
- ✅ No certificate installation on server

---

## Summary

**For Cloudflare Users:**

1. **Run on VPS:**
   ```bash
   ./skip-ssl.sh
   ```

2. **In Cloudflare:**
   - Set SSL mode to "Full"

3. **Done!**
   Visit https://air.arraystory.com

No need for Let's Encrypt when using Cloudflare! 🎉
