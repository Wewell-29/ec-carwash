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
    // Determine what changed
    const statusChanged = beforeData.status !== afterData.status;
    const beforeTs = beforeData.scheduledDateTime as admin.firestore.Timestamp | undefined;
    const afterTs = afterData.scheduledDateTime as admin.firestore.Timestamp | undefined;
    const scheduleChanged = !!(beforeTs && afterTs && beforeTs.toMillis() !== afterTs.toMillis());

    // If neither status nor schedule changed, skip
    if (!statusChanged && !scheduleChanged) {
      console.log(`Booking ${bookingId}: No relevant changes (status/schedule). Skipping notification.`);
      return null;
    }

    const newStatus = afterData.status;
    const userEmail = afterData.userEmail;

    if (statusChanged) {
      console.log(`Booking ${bookingId}: Status changed from ${beforeData.status} to ${newStatus}`);
    }

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

      if (statusChanged) {
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
      } else if (scheduleChanged) {
        // Reschedule notification
        const when = afterTs ? new Date(afterTs.toMillis()).toLocaleString("en-US", {
          year: "numeric", month: "short", day: "2-digit",
          hour: "2-digit", minute: "2-digit"
        }) : "a new time";
        notificationTitle = "Booking Rescheduled";
        notificationBody = `Your booking has been rescheduled to ${when}.`;
        notificationType = "booking_rescheduled";
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
          rescheduledAt: afterTs ? afterTs.toMillis().toString() : "",
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
 * Send push notification when an in-app Notification document is created
 * This covers cases like completed/cancelled/rescheduled created by the app
 */
export const sendNotificationOnCreate = functions.firestore
  .document("Notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const userEmail: string | undefined = data.userId;
    const type: string = data.type || "general";
    const title: string = data.title || "EC Carwash";
    const message: string = data.message || "You have a new notification";

    // Avoid duplicating booking_approved which is already handled by status trigger
    const allowed = [
      "booking_in_progress",
      "booking_completed",
      "booking_cancelled",
      "booking_rescheduled",
      "general",
    ];
    if (!allowed.includes(type)) {
      console.log(`Notification ${context.params.notificationId}: Type '${type}' not pushed`);
      return null;
    }

    if (!userEmail) {
      console.log(`Notification ${context.params.notificationId}: Missing userId/email`);
      return null;
    }

    try {
      const userSnapshot = await admin
        .firestore()
        .collection("Users")
        .where("email", "==", userEmail)
        .limit(1)
        .get();

      if (userSnapshot.empty) {
        console.log(`Notification ${context.params.notificationId}: No user doc for ${userEmail}`);
        return null;
      }

      const fcmToken = userSnapshot.docs[0].data().fcmToken as string | undefined;
      if (!fcmToken) {
        console.log(`Notification ${context.params.notificationId}: No FCM token for ${userEmail}`);
        return null;
      }

      const payload = {
        notification: {
          title,
          body: message,
        },
        data: {
          type,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          notificationId: context.params.notificationId,
        },
        token: fcmToken,
        android: {
          notification: {
            channelId: "booking_channel",
            priority: "high" as const,
            sound: "default",
          },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
      };

      const res = await admin.messaging().send(payload);
      console.log(`Pushed notification ${context.params.notificationId} to ${userEmail}: ${res}`);
      return null;
    } catch (e) {
      console.error(`Error pushing notification ${context.params.notificationId}:`, e);
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
