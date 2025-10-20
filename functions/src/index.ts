import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Send push notification when booking status changes
 * Triggers on any update to a booking document in Firestore
 */
export const sendBookingNotification = functions.firestore
  .document("Bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const bookingId = context.params.bookingId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed
    if (beforeData.status === afterData.status) {
      console.log(`Booking ${bookingId}: Status unchanged, skipping notification`);
      return null;
    }

    const newStatus = afterData.status;
    const userEmail = afterData.userEmail;

    console.log(`Booking ${bookingId}: Status changed from ${beforeData.status} to ${newStatus}`);

    if (!userEmail) {
      console.log(`Booking ${bookingId}: No user email found, skipping notification`);
      return null;
    }

    try {
      // Get the user's FCM token from Users collection
      const userSnapshot = await admin.firestore()
        .collection("Users")
        .where("email", "==", userEmail)
        .limit(1)
        .get();

      if (userSnapshot.empty) {
        console.log(`No user document found for email: ${userEmail}`);
        return null;
      }

      const userData = userSnapshot.docs[0].data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token found for user: ${userEmail}`);
        return null;
      }

      // Determine notification content based on status
      let notificationTitle = "";
      let notificationBody = "";
      let notificationType = "";

      switch (newStatus) {
      case "approved":
        notificationTitle = "Booking Confirmed!";
        notificationBody = "Your booking has been approved. We look forward to serving you!";
        notificationType = "booking_approved";
        break;
      case "in-progress":
        notificationTitle = "Service Started";
        notificationBody = "Your vehicle service is now in progress.";
        notificationType = "booking_in_progress";
        break;
      case "completed":
        notificationTitle = "Service Completed";
        notificationBody = "Your vehicle service has been completed. Thank you for choosing EC Carwash!";
        notificationType = "booking_completed";
        break;
      case "cancelled":
        notificationTitle = "Booking Cancelled";
        notificationBody = "Your booking has been cancelled.";
        notificationType = "booking_cancelled";
        break;
      default:
        console.log(`Booking ${bookingId}: Status '${newStatus}' does not trigger notification`);
        return null;
      }

      // Create the FCM message payload
      const message = {
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          bookingId: bookingId,
          status: newStatus,
          type: notificationType,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        token: fcmToken,
        // Android-specific options
        android: {
          notification: {
            channelId: "booking_channel",
            priority: "high" as const,
            sound: "default",
          },
        },
        // iOS-specific options
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      // Send the notification
      const response = await admin.messaging().send(message);
      console.log(`Successfully sent notification to ${userEmail}:`, response);

      return null;
    } catch (error) {
      console.error(`Error sending notification for booking ${bookingId}:`, error);
      return null;
    }
  });

/**
 * Clean up FCM token when user logs out
 * Optional: Triggers when a user document is deleted
 */
export const cleanupUserToken = functions.firestore
  .document("Users/{userId}")
  .onDelete(async (snap, context) => {
    const userData = snap.data();
    const fcmToken = userData.fcmToken;

    if (fcmToken) {
      console.log(`User ${context.params.userId} deleted, FCM token was: ${fcmToken}`);
      // Note: FCM tokens are automatically cleaned up by Firebase after a period of inactivity
      // No explicit cleanup needed here
    }

    return null;
  });

/**
 * Handle token refresh
 * Optional: Log when tokens are updated
 */
export const logTokenUpdate = functions.firestore
  .document("Users/{userId}")
  .onUpdate(async (change, context) => {
    const beforeToken = change.before.data().fcmToken;
    const afterToken = change.after.data().fcmToken;

    if (beforeToken !== afterToken) {
      console.log(`User ${context.params.userId} FCM token updated`);
      console.log(`Old token: ${beforeToken || "none"}`);
      console.log(`New token: ${afterToken || "none"}`);
    }

    return null;
  });
