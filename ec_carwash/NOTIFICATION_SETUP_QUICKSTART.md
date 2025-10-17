# Push Notification Quick Start Guide

## Customer App Changes (Already Done ✅)

All customer-side code has been implemented. Here's what was added:

### 1. New Dependencies
- `firebase_messaging: ^15.1.4` - For receiving push notifications
- `flutter_local_notifications: ^18.0.1` - For displaying notifications

### 2. New Service Files
- [lib/services/fcm_token_manager.dart](lib/services/fcm_token_manager.dart) - Manages FCM device tokens
- [lib/services/firebase_messaging_service.dart](lib/services/firebase_messaging_service.dart) - Handles incoming notifications
- [lib/services/local_notification_service.dart](lib/services/local_notification_service.dart) - Displays system notifications

### 3. Modified Files
- [lib/main.dart](lib/main.dart#L28-L33) - Initializes notification services on app start
- [lib/screens/Customer/customer_home.dart](lib/screens/Customer/customer_home.dart#L21-L35) - Refreshes FCM token when customer opens app
- [lib/data_models/booking_data_unified.dart](lib/data_models/booking_data_unified.dart#L316-L380) - Creates in-app notifications when booking status changes

## How It Works

### Customer App Flow
1. **User opens app** → FCM token is generated and saved to Firestore (`Users` collection)
2. **Admin approves booking** → In-app notification created automatically in `Notifications` collection
3. **Cloud Function triggers** (you need to set this up) → Push notification sent to user's device
4. **User receives notification** → Can tap to open app

### Notification Types
When you change a booking status, the following happens automatically:

| Status Change | Notification Title | Notification Type |
|--------------|-------------------|------------------|
| pending → **approved** | "Booking Confirmed!" | `booking_approved` |
| approved → **in-progress** | "Service Started" | `booking_in_progress` |
| in-progress → **completed** | "Service Completed" | `booking_completed` |
| any → **cancelled** | "Booking Cancelled" | `booking_cancelled` |

## What You Need to Do Next

### Step 1: Run Flutter Pub Get
```bash
cd /home/kentshin/Documents/commission-part-2/ec-carwash/ec_carwash
flutter pub get
```

### Step 2: Test the Customer App
1. Build and run the app on an Android device:
   ```bash
   flutter run
   ```
2. Login as a customer
3. Check Firebase Console → Firestore → `Users` collection
4. Verify your FCM token was saved

### Step 3: Test In-App Notifications
1. Create a booking from the customer app
2. Go to Admin panel (web app)
3. Change the booking status to "approved"
4. Open customer app → Notifications screen
5. You should see the notification

### Step 4: Set Up Push Notifications (Admin Side)

You have two options:

#### Option A: Firebase Cloud Functions (Recommended)
See [ADMIN_NOTIFICATION_SETUP.md](ADMIN_NOTIFICATION_SETUP.md#option-1-firebase-cloud-functions-recommended) for detailed instructions.

**Quick version:**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize Cloud Functions
firebase init functions

# Deploy the function (after implementing the code in the guide)
firebase deploy --only functions
```

#### Option B: Manual API Call from Admin App
See [ADMIN_NOTIFICATION_SETUP.md](ADMIN_NOTIFICATION_SETUP.md#option-2-manual-api-call-from-admin-app) for code examples.

### Step 5: Test Push Notifications
1. Close the customer app completely
2. From Admin panel, approve a booking
3. Customer device should receive a push notification
4. Tap notification → App opens

## Android Configuration Required

### AndroidManifest.xml

You may need to add notification permissions. Check if these exist in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <!-- Add these permissions if not already present -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application>
        <!-- Add this inside <application> tag if not already present -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="booking_channel" />
    </application>
</manifest>
```

## Firestore Collections

The app automatically creates/uses these collections:

### Users Collection
```
Users/
  {userId}/
    - email: "customer@example.com"
    - userId: "firebase_uid"
    - fcmToken: "device_token_here"
    - lastTokenUpdate: timestamp
```

### Notifications Collection
```
Notifications/
  {notificationId}/
    - userId: "customer@example.com"
    - title: "Booking Confirmed!"
    - message: "Your booking has been approved..."
    - type: "booking_approved"
    - isRead: false
    - createdAt: timestamp
    - metadata: {
        bookingId: "booking123",
        status: "approved"
      }
```

## Troubleshooting

### "Unable to resolve dependency"
```bash
flutter clean
flutter pub get
```

### "Permission denied" on Android 13+
The app automatically requests notification permissions. If user denied:
- Go to device Settings → Apps → EC Carwash → Notifications
- Enable notifications manually

### No FCM token in Firestore
- Check that user is logged in
- Check internet connection
- Check Firebase project configuration in `google-services.json`

### Push notifications not working
1. Verify FCM token exists in Firestore
2. Check that Cloud Function is deployed (if using Option A)
3. Check Cloud Function logs in Firebase Console
4. Verify device has internet connection
5. Test on a real device (not emulator)

## Files Changed Summary

```
Modified:
  - pubspec.yaml (added dependencies)
  - lib/main.dart (initialize notifications)
  - lib/screens/Customer/customer_home.dart (refresh FCM token)
  - lib/data_models/booking_data_unified.dart (create notifications)

Created:
  - lib/services/fcm_token_manager.dart
  - lib/services/firebase_messaging_service.dart
  - lib/services/local_notification_service.dart
  - ADMIN_NOTIFICATION_SETUP.md
  - NOTIFICATION_SETUP_QUICKSTART.md (this file)
```

## Next Steps Checklist

- [ ] Run `flutter pub get`
- [ ] Test customer app on Android device
- [ ] Verify FCM token saved in Firestore
- [ ] Test in-app notifications by approving a booking
- [ ] Set up Cloud Functions (or manual API) on Admin side
- [ ] Test push notifications with app closed
- [ ] Update Firestore security rules if needed

## Need Help?

- **Customer app issues**: Check the service files in `lib/services/`
- **Admin setup**: See [ADMIN_NOTIFICATION_SETUP.md](ADMIN_NOTIFICATION_SETUP.md)
- **Firebase errors**: Check Firebase Console → Functions → Logs
- **Firestore rules**: See the security rules section in ADMIN_NOTIFICATION_SETUP.md

---

**Ready to start?** Run `flutter pub get` and test the app!
