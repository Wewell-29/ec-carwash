# Admin-Side Push Notification Setup Guide

## Overview
This document outlines the **Admin-side changes** required to enable push notifications when bookings are confirmed. The Customer app is already set up to receive notifications - you just need to configure the backend to send them.

## What's Already Done (Customer Side)
✅ Firebase Cloud Messaging (FCM) integration
✅ Local notification handling
✅ FCM token storage in Firestore (`Users` collection)
✅ In-app notifications created automatically when booking status changes
✅ Notification permissions requested on app launch

## What You Need to Do (Admin Side)

### Option 1: Firebase Cloud Functions (Recommended)

Firebase Cloud Functions will automatically send push notifications whenever a booking status changes in Firestore.

#### Step 1: Install Firebase CLI and Initialize Functions
```bash
# Install Firebase CLI globally (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Navigate to your project directory
cd /path/to/ec-carwash

# Initialize Cloud Functions
firebase init functions
```

Select:
- TypeScript or JavaScript (your choice)
- Install dependencies with npm

#### Step 2: Create the Cloud Function

Create or edit `functions/src/index.ts` (TypeScript) or `functions/index.js` (JavaScript):

**TypeScript Version:**
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

/**
 * Send push notification when booking status changes to 'approved'
 */
export const sendBookingNotification = functions.firestore
  .document('Bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const bookingId = context.params.bookingId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed to 'approved'
    if (beforeData.status !== 'approved' && afterData.status === 'approved') {
      const userEmail = afterData.userEmail;

      // Get the user's FCM token from Users collection
      const userDoc = await admin.firestore()
        .collection('Users')
        .where('email', '==', userEmail)
        .limit(1)
        .get();

      if (userDoc.empty) {
        console.log(`No user found with email: ${userEmail}`);
        return null;
      }

      const userData = userDoc.docs[0].data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token found for user: ${userEmail}`);
        return null;
      }

      // Create the push notification payload
      const payload = {
        notification: {
          title: 'Booking Confirmed!',
          body: 'Your booking has been approved. We look forward to serving you!',
        },
        data: {
          bookingId: bookingId,
          status: 'approved',
          type: 'booking_approved',
        },
        token: fcmToken,
      };

      // Send the notification
      try {
        await admin.messaging().send(payload);
        console.log(`Notification sent successfully to ${userEmail}`);
        return null;
      } catch (error) {
        console.error('Error sending notification:', error);
        return null;
      }
    }

    // Handle other status changes (optional)
    if (afterData.status === 'in-progress' && beforeData.status !== 'in-progress') {
      // Send notification for in-progress status
      // Similar logic as above
    }

    if (afterData.status === 'completed' && beforeData.status !== 'completed') {
      // Send notification for completed status
      // Similar logic as above
    }

    return null;
  });
```

**JavaScript Version:**
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Send push notification when booking status changes to 'approved'
 */
exports.sendBookingNotification = functions.firestore
  .document('Bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const bookingId = context.params.bookingId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed to 'approved'
    if (beforeData.status !== 'approved' && afterData.status === 'approved') {
      const userEmail = afterData.userEmail;

      // Get the user's FCM token from Users collection
      const userDoc = await admin.firestore()
        .collection('Users')
        .where('email', '==', userEmail)
        .limit(1)
        .get();

      if (userDoc.empty) {
        console.log(`No user found with email: ${userEmail}`);
        return null;
      }

      const userData = userDoc.docs[0].data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token found for user: ${userEmail}`);
        return null;
      }

      // Create the push notification payload
      const payload = {
        notification: {
          title: 'Booking Confirmed!',
          body: 'Your booking has been approved. We look forward to serving you!',
        },
        data: {
          bookingId: bookingId,
          status: 'approved',
          type: 'booking_approved',
        },
        token: fcmToken,
      };

      // Send the notification
      try {
        await admin.messaging().send(payload);
        console.log(`Notification sent successfully to ${userEmail}`);
        return null;
      } catch (error) {
        console.error('Error sending notification:', error);
        return null;
      }
    }

    return null;
  });
```

#### Step 3: Install Required Dependencies

In the `functions` directory:
```bash
cd functions
npm install firebase-admin firebase-functions
```

#### Step 4: Deploy the Cloud Function
```bash
firebase deploy --only functions
```

#### Step 5: Verify Deployment
- Go to Firebase Console → Functions
- You should see `sendBookingNotification` listed
- Test by approving a booking from the Admin panel

---

### Option 2: Manual API Call from Admin App

If you prefer to send notifications directly from your Admin web app when approving bookings, you can use the FCM REST API.

#### Step 1: Get Your Server Key
1. Go to Firebase Console → Project Settings → Cloud Messaging
2. Find your **Server Key** (or use Service Account JSON)

#### Step 2: Add Notification Logic to Admin Scheduling Screen

When the admin approves a booking (changes status to 'approved'), call this function:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendPushNotification({
  required String fcmToken,
  required String title,
  required String body,
  required Map<String, String> data,
}) async {
  const String serverKey = 'YOUR_FIREBASE_SERVER_KEY_HERE';
  const String fcmUrl = 'https://fcm.googleapis.com/fcm/send';

  try {
    final response = await http.post(
      Uri.parse(fcmUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode({
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data,
        'priority': 'high',
      }),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.statusCode}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}

// Usage: When approving a booking
Future<void> approveBookingWithNotification(String bookingId) async {
  // Get booking details
  final bookingDoc = await FirebaseFirestore.instance
      .collection('Bookings')
      .doc(bookingId)
      .get();

  final bookingData = bookingDoc.data()!;
  final userEmail = bookingData['userEmail'];

  // Update booking status
  await BookingManager.updateBookingStatus(bookingId, 'approved');

  // Get user's FCM token
  final userQuery = await FirebaseFirestore.instance
      .collection('Users')
      .where('email', isEqualTo: userEmail)
      .limit(1)
      .get();

  if (userQuery.docs.isNotEmpty) {
    final fcmToken = userQuery.docs.first.data()['fcmToken'];

    if (fcmToken != null) {
      await sendPushNotification(
        fcmToken: fcmToken,
        title: 'Booking Confirmed!',
        body: 'Your booking has been approved. We look forward to serving you!',
        data: {
          'bookingId': bookingId,
          'status': 'approved',
          'type': 'booking_approved',
        },
      );
    }
  }
}
```

**Note:** You'll need to add the `http` package to your Admin app's `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
```

---

## Database Structure

The Customer app automatically creates the following Firestore structure:

### Users Collection
```
Users/{userId}
  - email: string
  - userId: string
  - fcmToken: string (device token for push notifications)
  - lastTokenUpdate: timestamp
```

### Notifications Collection
```
Notifications/{notificationId}
  - userId: string (user email)
  - title: string
  - message: string
  - type: string (booking_approved, booking_in_progress, booking_completed, etc.)
  - isRead: boolean
  - createdAt: timestamp
  - metadata: {
      bookingId: string,
      status: string
    }
```

---

## Testing the Implementation

### 1. Test FCM Token Storage
- Open the Customer app on an Android device
- Login with a customer account
- Check Firestore → Users collection
- Verify that a document exists with the user's `fcmToken`

### 2. Test In-App Notifications
- From Admin panel, change a booking status to 'approved'
- Open Customer app → Notifications screen
- You should see the notification appear

### 3. Test Push Notifications
- Close the Customer app completely
- From Admin panel, approve a booking
- Customer device should receive a push notification
- Tap the notification to open the app

---

## Troubleshooting

### No Push Notifications Received
1. **Check FCM Token**: Verify the token exists in Firestore (`Users` collection)
2. **Check Cloud Function Logs**: Firebase Console → Functions → Logs
3. **Check Permissions**: User must have granted notification permissions
4. **Check Network**: Device must have internet connection

### In-App Notifications Not Showing
1. **Check Firestore Rules**: Ensure the app can read from `Notifications` collection
2. **Check User Email**: Ensure `userEmail` in booking matches `userId` in notification

### Cloud Function Not Triggering
1. **Check Deployment**: Run `firebase deploy --only functions` again
2. **Check Billing**: Cloud Functions require Blaze plan (which you have)
3. **Check Logs**: Firebase Console → Functions → Logs for errors

---

## Firestore Security Rules

Ensure your Firestore rules allow the necessary operations:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users collection - allow users to read/write their own token
    match /Users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Notifications collection - users can only read their own notifications
    match /Notifications/{notificationId} {
      allow read: if request.auth != null &&
                     resource.data.userId == request.auth.token.email;
      allow write: if request.auth != null; // Admin creates notifications
    }

    // Bookings - existing rules apply
    match /Bookings/{bookingId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // Adjust based on your needs
    }
  }
}
```

---

## Recommendations

1. **Use Cloud Functions (Option 1)** - More reliable, scalable, and automatic
2. **Monitor Function Logs** - Check for errors regularly
3. **Handle Token Expiry** - FCM tokens can expire; the app refreshes them automatically
4. **Test on Real Device** - Emulators don't support push notifications
5. **Enable Background Notifications** - Already configured in the Customer app

---

## Next Steps

1. Choose Option 1 (Cloud Functions) or Option 2 (Manual API)
2. Implement the chosen approach
3. Test thoroughly with real devices
4. Monitor Firebase Console for errors
5. Consider adding analytics to track notification delivery rates

---

## Contact
If you need help with the Admin-side implementation, please coordinate with the development team before making changes to production code.
