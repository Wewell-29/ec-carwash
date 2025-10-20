# 🚀 Quick Deployment Steps

## Follow these steps in order:

---

## ✅ STEP 1: Customer App Setup (5 minutes)

### 1.1 Install Flutter Dependencies
```bash
cd /home/kentshin/Documents/commission-part-2/ec-carwash/ec_carwash
flutter pub get
```

### 1.2 Run on Android Device
```bash
flutter run
```

### 1.3 Test In-App Notifications
1. Login as a customer
2. Create a booking
3. Go to Admin panel (web)
4. Approve the booking
5. Open customer app → Notifications screen
6. ✅ You should see "Booking Confirmed!" notification

**If this works, proceed to Step 2** ✅

---

## ✅ STEP 2: Firebase Cloud Functions Setup (10 minutes)

### 2.1 Install Firebase CLI (if needed)
```bash
npm install -g firebase-tools
```

### 2.2 Login to Firebase
```bash
firebase login
```

### 2.3 Navigate to Project Root
```bash
cd /home/kentshin/Documents/commission-part-2/ec-carwash
```

### 2.4 List Your Firebase Projects
```bash
firebase projects:list
```

### 2.5 Set Your Project
```bash
# Replace <your-project-id> with your actual Firebase project ID
firebase use <your-project-id>

# Example:
# firebase use ec-carwash-12345
```

### 2.6 Deploy Cloud Functions
```bash
firebase deploy --only functions
```

**Expected Output:**
```
✔  Deploy complete!

Functions:
  sendBookingNotification(us-central1)
  cleanupUserToken(us-central1)
  logTokenUpdate(us-central1)
```

---

## ✅ STEP 3: Test Push Notifications (5 minutes)

### 3.1 Verify FCM Token Saved
1. Open Firebase Console → Firestore
2. Go to `Users` collection
3. Find your customer user document
4. ✅ Verify `fcmToken` field exists

### 3.2 Test Push Notification
1. **Close customer app completely** (kill it, don't just minimize)
2. Go to Admin panel
3. Approve a pending booking
4. ✅ Customer device should receive push notification

### 3.3 Check Cloud Function Logs
```bash
firebase functions:log --only sendBookingNotification --limit 10
```

**Look for:**
```
Booking xyz123: Status changed from pending to approved
Successfully sent notification to customer@example.com
```

---

## ✅ STEP 4: Verify Everything Works

### Checklist:
- [ ] Customer app runs without errors
- [ ] In-app notifications appear when booking approved
- [ ] FCM token saved in Firestore Users collection
- [ ] Cloud Functions deployed successfully
- [ ] Push notifications received (app closed)
- [ ] Logs show successful notification delivery

---

## 🔍 Troubleshooting

### Issue: `flutter: command not found`
```bash
# Install Flutter or add to PATH
export PATH="$PATH:/path/to/flutter/bin"
```

### Issue: `firebase: command not found`
```bash
npm install -g firebase-tools
```

### Issue: "No project active"
```bash
firebase use <your-project-id>
```

### Issue: No push notification received
1. Verify FCM token exists in Firestore
2. Check function logs: `firebase functions:log --tail`
3. Test on real Android device (not emulator)
4. Ensure app is completely closed

### Issue: Build errors in customer app
```bash
cd ec_carwash
flutter clean
flutter pub get
flutter run
```

---

## 📞 Need Help?

### View Detailed Docs:
- **Customer App**: [NOTIFICATION_SETUP_QUICKSTART.md](ec_carwash/NOTIFICATION_SETUP_QUICKSTART.md)
- **Cloud Functions**: [CLOUD_FUNCTIONS_DEPLOYMENT.md](CLOUD_FUNCTIONS_DEPLOYMENT.md)
- **Complete Guide**: [PUSH_NOTIFICATIONS_COMPLETE.md](PUSH_NOTIFICATIONS_COMPLETE.md)

### View Logs:
```bash
# Real-time Cloud Function logs
firebase functions:log --tail

# Filter by function
firebase functions:log --only sendBookingNotification
```

### Firebase Console:
- Functions: https://console.firebase.google.com → Functions
- Firestore: https://console.firebase.google.com → Firestore
- Logs: https://console.firebase.google.com → Functions → Logs

---

## 🎯 Success!

When you see:
- ✅ In-app notification in customer app
- ✅ Push notification on device (app closed)
- ✅ "Successfully sent notification" in logs

**You're done! 🎉**

---

## Quick Commands Summary

```bash
# 1. Customer App
cd ec_carwash
flutter pub get
flutter run

# 2. Cloud Functions
cd /home/kentshin/Documents/commission-part-2/ec-carwash
firebase login
firebase use <project-id>
firebase deploy --only functions

# 3. Check Logs
firebase functions:log --tail
```

---

**Start now:** `cd ec_carwash && flutter pub get`
