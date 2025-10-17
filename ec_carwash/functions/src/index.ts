import {onDocumentUpdated, onDocumentDeleted} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Send push notification when booking status changes
 * Triggers on any update to a booking document in Firestore
 */
export const sendBookingNotification = onDocumentUpdated(
  "Bookings/{bookingId}",
  async (event) => {
    const bookingId = event.params.bookingId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) {
      logger.warn(`Booking ${bookingId}: Missing data`);
      return;
    }

    // Check if status changed
    if (beforeData.status === afterData.status) {
      logger.info(`Booking ${bookingId}: Status unchanged, skipping notification`);
      return;
    }

    const newStatus = afterData.status;
    const userEmail = afterData.userEmail;

    logger.info(`Booking ${bookingId}: Status changed from ${beforeData.status} to ${newStatus}`);

    if (!userEmail) {
      logger.warn(`Booking ${bookingId}: No user email found, skipping notification`);
      return;
    }

    try {
      // Get the user's FCM token from Users collection
      const userSnapshot = await admin.firestore()
        .collection("Users")
        .where("email", "==", userEmail)
        .limit(1)
        .get();

      if (userSnapshot.empty) {
        logger.warn(`No user document found for email: ${userEmail}`);
        return;
      }

      const userData = userSnapshot.docs[0].data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        logger.warn(`No FCM token found for user: ${userEmail}`);
        return;
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
        logger.info(`Booking ${bookingId}: Status '${newStatus}' does not trigger notification`);
        return;
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
      logger.info(`Successfully sent notification to ${userEmail}:`, response);
    } catch (error) {
      logger.error(`Error sending notification for booking ${bookingId}:`, error);
    }
  }
);

/**
 * Clean up FCM token when user logs out
 * Optional: Triggers when a user document is deleted
 */
export const cleanupUserToken = onDocumentDeleted(
  "Users/{userId}",
  async (event) => {
    const userData = event.data?.data();
    const userId = event.params.userId;

    if (!userData) {
      logger.warn(`User ${userId}: No data found`);
      return;
    }

    const fcmToken = userData.fcmToken;

    if (fcmToken) {
      logger.info(`User ${userId} deleted, FCM token was: ${fcmToken}`);
      // Note: FCM tokens are automatically cleaned up by Firebase after a period of inactivity
      // No explicit cleanup needed here
    }
  }
);

/**
 * Handle token refresh
 * Optional: Log when tokens are updated
 */
export const logTokenUpdate = onDocumentUpdated(
  "Users/{userId}",
  async (event) => {
    const beforeToken = event.data?.before.data()?.fcmToken;
    const afterToken = event.data?.after.data()?.fcmToken;
    const userId = event.params.userId;

    if (beforeToken !== afterToken) {
      logger.info(`User ${userId} FCM token updated`);
      logger.info(`Old token: ${beforeToken || "none"}`);
      logger.info(`New token: ${afterToken || "none"}`);
    }
  }
);
