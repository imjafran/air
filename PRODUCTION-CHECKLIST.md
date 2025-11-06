# Production Deployment Checklist

## ✅ Pre-Deployment (Local)

- [x] All code changes committed
- [x] Updated main.go with new features
- [x] Updated air.js client library (production minified)
- [x] Updated index.html with new UI
- [x] Updated nginx-cloudflare.conf
- [x] Created deployment scripts
- [x] Updated API documentation

## 🚀 Deploy to Production (VPS)

### Step 1: Push to Git
```bash
git add .
git commit -m "feat: added user tracking, typing indicators, image/file upload, enhanced UI"
git push origin main
```

### Step 2: On VPS - Pull & Deploy
```bash
ssh user@13.232.180.232
cd ~/realtime
git pull
docker compose -f docker-compose.cloudflare.yml down
docker compose -f docker-compose.cloudflare.yml build --no-cache
docker compose -f docker-compose.cloudflare.yml up -d
sleep 15
docker compose -f docker-compose.cloudflare.yml restart go-app
```

### Step 3: Verify Deployment
```bash
# Check containers
docker compose -f docker-compose.cloudflare.yml ps

# Check logs
docker compose -f docker-compose.cloudflare.yml logs -f go-app
```

## ✅ Post-Deployment Testing

### Test Checklist:
- [ ] Visit https://air.arraystory.com
- [ ] Connection status shows "Connected"
- [ ] Enter name and join chat
- [ ] Send text message - works
- [ ] Upload image (< 2MB) - works
- [ ] Upload file (< 2MB) - works  
- [ ] Type to see typing indicator - works
- [ ] User list shows in footer - works
- [ ] Open 2nd browser/device - multi-user works
- [ ] Check /air.js loads - works
- [ ] Verify CORS (only whitelisted domains) - works

### Check Database
- [ ] Access Adminer: http://13.232.180.232:8283
- [ ] Verify room 'demo' exists
- [ ] Verify domain 'air.arraystory.com' whitelisted

## 📋 New Features Deployed

✅ **User Tracking**
- User ID & name required on connect
- Real-time user list
- Join/leave notifications

✅ **Direct Messaging**
- sendTo(userId, data) for private messages
- onDirect() event listener

✅ **Typing Indicators**
- typing() method (auto-debounced)
- onTyping() event listener
- Shows who's typing in real-time

✅ **Enhanced UI**
- Image upload (< 2MB)
- File upload (< 2MB)
- Mobile responsive
- User list in footer
- Typing indicators display
- Modern gradient design
- ArrayStory branding

✅ **CORS Protection**
- /air.js only for whitelisted domains
- Enhanced security

✅ **Updated API**
- New methods: sendTo(), typing(), getUsers(), getUserCount()
- New events: onDirect(), onUserList(), onJoin(), onLeave(), onTyping()
- Complete documentation in API-DOCS.md

## 🔍 Monitoring

```bash
# Watch logs
docker compose -f docker-compose.cloudflare.yml logs -f

# Check resources
docker stats

# Container status
docker compose -f docker-compose.cloudflare.yml ps
```

## 🚨 If Something Goes Wrong

### Rollback
```bash
git reset --hard HEAD~1
git pull
docker compose -f docker-compose.cloudflare.yml down
docker compose -f docker-compose.cloudflare.yml build --no-cache
docker compose -f docker-compose.cloudflare.yml up -d
sleep 15
docker compose -f docker-compose.cloudflare.yml restart go-app
```

### Common Issues

**Database Connection Failed:**
```bash
sleep 15
docker compose -f docker-compose.cloudflare.yml restart go-app
```

**WebSocket Not Connecting:**
- Check domain whitelisted
- Verify room exists
- Check Cloudflare proxy enabled

**Static Files 404:**
```bash
docker compose -f docker-compose.cloudflare.yml restart nginx
```

## 📞 Support

- API Docs: API-DOCS.md
- Deploy Guide: VPS-DEPLOY.md
- Check logs for detailed errors

---

**Ready to deploy! 🎉**
