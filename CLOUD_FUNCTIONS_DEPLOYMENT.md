# Cloud Functions Deployment Guide

## ✅ Setup Complete!

All Cloud Functions code is ready. The functions will automatically send push notifications when booking status changes.

## 📋 What's Been Set Up

### Cloud Functions Created:
1. **`sendBookingNotification`** - Main function that sends push notifications
2. **`cleanupUserToken`** - Logs when users are deleted (optional)
3. **`logTokenUpdate`** - Logs FCM token updates (optional)

### Project Structure:
```
/home/kentshin/Documents/commission-part-2/ec-carwash/
├── functions/
│   ├── src/
│   │   └── index.ts          ✅ Cloud Function code
│   ├── lib/                   ✅ Compiled JavaScript
│   ├── package.json          ✅ Dependencies installed
│   ├── tsconfig.json         ✅ TypeScript config
│   └── README.md             ✅ Function documentation
├── firebase.json             ✅ Firebase configuration
└── CLOUD_FUNCTIONS_DEPLOYMENT.md (this file)
```

## 🚀 Deployment Steps

### Step 1: Verify Firebase CLI Installation
```bash
firebase --version
```

If not installed:
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Set Your Firebase Project
```bash
# From project root
cd /home/kentshin/Documents/commission-part-2/ec-carwash

# List your Firebase projects
firebase projects:list

# Set the active project (replace with your project ID)
firebase use <your-project-id>

# Example:
# firebase use ec-carwash-app
```

### Step 4: Deploy Cloud Functions
```bash
# Deploy all functions
firebase deploy --only functions

# OR deploy specific function
firebase deploy --only functions:sendBookingNotification
```

**Expected output:**
```
✔  Deploy complete!

Functions:
  sendBookingNotification(us-central1)
  cleanupUserToken(us-central1)
  logTokenUpdate(us-central1)
```

### Step 5: Verify Deployment
```bash
# List deployed functions
firebase functions:list

# View logs
firebase functions:log --only sendBookingNotification
```

## 🧪 Testing the Notification System

### Test Flow:
1. **Customer App**: Login and create a booking
2. **Admin Panel**: Go to scheduling and approve the booking
3. **Expected Results**:
   - ✅ In-app notification created in Firestore (`Notifications` collection)
   - ✅ Push notification sent to customer's device
   - ✅ Customer receives notification (even if app is closed)

### Debug Steps:
```bash
# Watch real-time logs
firebase functions:log --only sendBookingNotification --tail

# Check specific time period
firebase functions:log --only sendBookingNotification --limit 50
```

### What to Look For in Logs:
```
Booking xyz123: Status changed from pending to approved
Successfully sent notification to customer@example.com: projects/.../messages/...
```

## 🔍 Troubleshooting

### Issue: "Firebase CLI not found"
**Solution:**
```bash
npm install -g firebase-tools
firebase login
```

### Issue: "Billing account not configured"
**Solution:**
- Cloud Functions require Firebase Blaze (pay-as-you-go) plan
- Go to Firebase Console → Upgrade to Blaze plan
- You mentioned the plan is already upgraded ✅

### Issue: "No FCM token found for user"
**Solution:**
1. Open customer app
2. Login with the customer account
3. Check Firestore → `Users` collection
4. Verify user document has `fcmToken` field

### Issue: "Function not triggering"
**Solution:**
```bash
# Check function is deployed
firebase functions:list

# Check Firestore rules allow reading Users collection
# Go to Firebase Console → Firestore → Rules
```

### Issue: "Push notification not received"
**Solution:**
1. Test on real Android device (not emulator)
2. Verify notification permissions are granted
3. Check app is logged in with same email as booking
4. Close app completely and test again

## 📊 How It Works

```
1. Admin approves booking in Firestore
   Bookings/{bookingId}
   status: "pending" → "approved"

2. Cloud Function "sendBookingNotification" triggers automatically

3. Function queries Users collection for FCM token
   Users/{userId}
   email: "customer@example.com"
   fcmToken: "device_fcm_token_here"

4. Function sends FCM push notification

5. Customer receives notification on device
   (even if app is closed)
```

## 💰 Cost Information

**Blaze Plan Pricing:**
- First 2 million function invocations/month: **FREE**
- First 400,000 GB-seconds compute time/month: **FREE**
- First 5 GB network egress/month: **FREE**

**Estimated Monthly Cost:**
- ~1,000 bookings/month = ~1,000 function calls
- **Total cost: $0** (well within free tier)

## 🔐 Security Notes

### Firestore Security Rules
Ensure your `firestore.rules` allow Cloud Functions to access the Users collection:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users collection - allow functions to read
    match /Users/{userId} {
      allow read: if true; // Functions need to read FCM tokens
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // Notifications collection
    match /Notifications/{notificationId} {
      allow read: if request.auth != null &&
                     resource.data.userId == request.auth.token.email;
      allow write: if true; // Allow functions to create notifications
    }

    // Bookings collection
    match /Bookings/{bookingId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 📝 Maintenance

### Update Functions
1. Edit `functions/src/index.ts`
2. Build: `cd functions && npm run build`
3. Deploy: `firebase deploy --only functions`

### View Logs Anytime
```bash
# Real-time logs
firebase functions:log --tail

# Filter by function
firebase functions:log --only sendBookingNotification

# View errors only
firebase functions:log --only sendBookingNotification | grep ERROR
```

### Delete a Function
```bash
firebase functions:delete sendBookingNotification
```

## ✅ Final Checklist

Before going live:

- [ ] Firebase CLI installed and logged in
- [ ] Firebase project set (`firebase use <project-id>`)
- [ ] Blaze plan active ✅ (you mentioned this is done)
- [ ] Functions deployed (`firebase deploy --only functions`)
- [ ] Functions visible in Firebase Console
- [ ] Firestore security rules updated
- [ ] Customer app tested (FCM token saved)
- [ ] Test booking approval sends notification
- [ ] Logs show successful notification delivery

## 🆘 Quick Commands Reference

```bash
# Login
firebase login

# Set project
firebase use <project-id>

# Deploy functions
firebase deploy --only functions

# List functions
firebase functions:list

# View logs
firebase functions:log --tail

# Build TypeScript (from functions dir)
cd functions
npm run build
```

## 🎯 Next Steps

1. **Deploy Now:**
   ```bash
   cd /home/kentshin/Documents/commission-part-2/ec-carwash
   firebase use <your-project-id>
   firebase deploy --only functions
   ```

2. **Test the Flow:**
   - Open customer app
   - Create a booking
   - Approve from admin panel
   - Verify notification received

3. **Monitor:**
   ```bash
   firebase functions:log --tail
   ```

4. **Celebrate! 🎉**
   Your push notification system is live!

---

## 📞 Support

- **Firebase Console**: https://console.firebase.google.com
- **Functions Documentation**: See [functions/README.md](functions/README.md)
- **Customer App Setup**: See [NOTIFICATION_SETUP_QUICKSTART.md](ec_carwash/NOTIFICATION_SETUP_QUICKSTART.md)

---

**Status:** Cloud Functions are built and ready to deploy!

**Command to deploy:**
```bash
firebase deploy --only functions
```
