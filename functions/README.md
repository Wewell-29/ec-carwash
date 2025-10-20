# EC Carwash Cloud Functions

Firebase Cloud Functions for automatic push notifications when booking status changes.

## 📋 What This Does

Automatically sends push notifications to customers when:
- Booking is **approved** → "Booking Confirmed!"
- Booking is **in-progress** → "Service Started"
- Booking is **completed** → "Service Completed"
- Booking is **cancelled** → "Booking Cancelled"

## 🚀 Setup Instructions

### Prerequisites
- Node.js 18 or higher
- Firebase CLI installed globally
- Firebase project with Blaze (pay-as-you-go) plan

### Step 1: Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Initialize Firebase (if not already done)
```bash
# Run from project root: /home/kentshin/Documents/commission-part-2/ec-carwash
firebase init

# Select:
# - Functions (already configured)
# - Use existing project: ec-carwash (or your project ID)
# - TypeScript
# - Use ESLint: Yes
# - Install dependencies: Yes
```

### Step 4: Install Dependencies
```bash
cd functions
npm install
```

### Step 5: Build TypeScript
```bash
npm run build
```

### Step 6: Deploy to Firebase
```bash
# From functions directory
npm run deploy

# OR from project root
firebase deploy --only functions
```

## 📁 File Structure

```
functions/
├── src/
│   └── index.ts              # Main Cloud Functions code
├── lib/                       # Compiled JavaScript (generated)
├── package.json              # Dependencies and scripts
├── tsconfig.json             # TypeScript configuration
├── .eslintrc.js              # ESLint configuration
├── .gitignore                # Git ignore rules
└── README.md                 # This file
```

## 🔧 Available Functions

### 1. `sendBookingNotification`
**Trigger:** Firestore `Bookings/{bookingId}` document update
**Purpose:** Sends push notification when booking status changes

**How it works:**
1. Detects booking status change in Firestore
2. Gets customer's FCM token from `Users` collection
3. Sends appropriate push notification based on new status
4. Logs success/failure for debugging

### 2. `cleanupUserToken` (Optional)
**Trigger:** Firestore `Users/{userId}` document deletion
**Purpose:** Logs when user documents are deleted

### 3. `logTokenUpdate` (Optional)
**Trigger:** Firestore `Users/{userId}` document update
**Purpose:** Logs FCM token changes for debugging

## 🧪 Testing

### Test Locally (Emulator)
```bash
npm run serve
```

### Test in Production
1. Deploy functions: `npm run deploy`
2. Open customer app and login
3. Create a booking
4. Go to Admin panel and approve the booking
5. Customer should receive push notification

### View Logs
```bash
# Real-time logs
firebase functions:log

# OR view in Firebase Console
# https://console.firebase.google.com → Functions → Logs
```

## 📊 Expected Flow

```
Admin approves booking
        ↓
Firestore: Bookings/{id}
status: "approved"
        ↓
Cloud Function triggers
        ↓
Query Users collection
for FCM token
        ↓
Send FCM message
        ↓
Customer receives
push notification
```

## 🔍 Troubleshooting

### Function Not Triggering
- Check Firebase Console → Functions → Logs for errors
- Verify function is deployed: `firebase functions:list`
- Check Firestore security rules allow function to read Users collection

### No Push Notification Received
- Verify FCM token exists in Users/{userId} document
- Check function logs for "No FCM token found" errors
- Test on real Android device (not emulator)
- Verify customer app has notification permissions

### Build Errors
```bash
cd functions
npm install
npm run build
```

### Deployment Errors
- Ensure Blaze plan is active
- Check Firebase project has Cloud Functions enabled
- Verify authentication: `firebase login`

## 💰 Cost Estimate

Cloud Functions pricing (Blaze plan):
- **Invocations:** First 2 million/month free
- **Compute time:** First 400,000 GB-seconds/month free
- **Network:** First 5 GB/month free

**Estimated cost for typical usage:**
- ~1000 bookings/month = ~1000 function invocations
- **Cost: $0** (well within free tier)

## 🔐 Security

The functions run with admin privileges and can:
- Read from any Firestore collection
- Send FCM messages to any token

**Best practices:**
- Don't expose admin SDK credentials
- Keep functions code in private repository
- Monitor function logs regularly

## 📝 Maintenance

### Update Dependencies
```bash
cd functions
npm update
npm audit fix
```

### Redeploy After Changes
```bash
npm run build
npm run deploy
```

## 🆘 Support

### Common Commands
```bash
# View deployed functions
firebase functions:list

# View function logs
firebase functions:log

# Delete a function
firebase functions:delete sendBookingNotification

# Deploy specific function
firebase deploy --only functions:sendBookingNotification
```

### Useful Links
- [Firebase Functions Docs](https://firebase.google.com/docs/functions)
- [FCM Server Reference](https://firebase.google.com/docs/cloud-messaging/server)
- [Firebase Console](https://console.firebase.google.com)

## ✅ Checklist

- [ ] Node.js 18+ installed
- [ ] Firebase CLI installed (`npm install -g firebase-tools`)
- [ ] Logged in to Firebase (`firebase login`)
- [ ] Dependencies installed (`cd functions && npm install`)
- [ ] TypeScript compiled (`npm run build`)
- [ ] Functions deployed (`npm run deploy`)
- [ ] Tested with real booking approval
- [ ] Verified logs in Firebase Console

---

**Status:** Ready to deploy! Run `npm install` in the functions directory, then `npm run deploy`.
