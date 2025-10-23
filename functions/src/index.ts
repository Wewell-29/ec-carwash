import { onDocumentUpdated, onDocumentDeleted, onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Preferred locale/timezone for human-readable times in messages
const DEFAULT_LOCALE = process.env.APP_LOCALE || "en-PH";
const DEFAULT_TIME_ZONE = process.env.APP_TIME_ZONE || "Asia/Manila";

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

    const statusChanged = beforeData.status !== afterData.status;
    const beforeTs = beforeData.scheduledDateTime as admin.firestore.Timestamp | undefined;
    const afterTs = afterData.scheduledDateTime as admin.firestore.Timestamp | undefined;
    const scheduleChanged = !!(beforeTs && afterTs && beforeTs.toMillis() !== afterTs.toMillis());

    if (!statusChanged && !scheduleChanged) {
      logger.info(`Booking ${bookingId}: No relevant changes (status/schedule). Skipping notification.`);
      return;
    }

    const newStatus = afterData.status;
    const userEmail = afterData.userEmail as string | undefined;

    if (statusChanged) {
      logger.info(`Booking ${bookingId}: Status changed from ${beforeData.status} to ${newStatus}`);
    }

    if (!userEmail) {
      logger.warn(`Booking ${bookingId}: No user email found, skipping notification`);
      return;
    }

    try {
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
      const fcmToken = userData.fcmToken as string | undefined;

      if (!fcmToken) {
        logger.warn(`No FCM token found for user: ${userEmail}`);
        return;
      }

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
          logger.info(`Booking ${bookingId}: Status '${newStatus}' does not trigger notification`);
          return;
        }
      } else if (scheduleChanged) {
        const when = afterTs
          ? new Date(afterTs.toMillis()).toLocaleString(DEFAULT_LOCALE, {
              timeZone: DEFAULT_TIME_ZONE,
              year: "numeric",
              month: "short",
              day: "2-digit",
              hour: "2-digit",
              minute: "2-digit",
              hour12: true,
            })
          : "a new time";
        notificationTitle = "Booking Rescheduled";
        notificationBody = `Your booking has been rescheduled to ${when}.`;
        notificationType = "booking_rescheduled";
      }

      const message: any = {
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
        android: { notification: { channelId: "booking_channel", priority: "high", sound: "default" } },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
      };

      const response = await admin.messaging().send(message);
      logger.info(`Successfully sent notification to ${userEmail}: ${response}`);

    } catch (error) {
      logger.error(`Error sending notification for booking ${bookingId}:`, error);
    }
  }
);

/**
 * Send push notification when an in-app Notification document is created
 * This covers cases like completed/cancelled/rescheduled created by the app
 */
export const sendNotificationOnCreate = onDocumentCreated(
  "Notifications/{notificationId}",
  async (event) => {
    const data = event.data?.data() as any;
    const userEmail: string | undefined = data.userId;
    const type: string = data.type || "general";
    const title: string = data.title || "EC Carwash";
    const message: string = data.message || "You have a new notification";

    // Avoid duplicating booking_approved which is already handled by status trigger
    // Only push for generic messages; booking_* notifications are handled by Bookings trigger
    const allowed = [
      "general",
    ];
    if (!allowed.includes(type)) {
      logger.info(`Notification ${event.params.notificationId}: Type '${type}' not pushed`);
      return;
    }

    if (!userEmail) {
      logger.warn(`Notification ${event.params.notificationId}: Missing userId/email`);
      return;
    }

    try {
      const userSnapshot = await admin
        .firestore()
        .collection("Users")
        .where("email", "==", userEmail)
        .limit(1)
        .get();

      if (userSnapshot.empty) {
        logger.warn(`Notification ${event.params.notificationId}: No user doc for ${userEmail}`);
        return;
      }

      const fcmToken = userSnapshot.docs[0].data().fcmToken as string | undefined;
      if (!fcmToken) {
        logger.warn(`Notification ${event.params.notificationId}: No FCM token for ${userEmail}`);
        return;
      }

      const payload = {
        notification: {
          title,
          body: message,
        },
        data: {
          type,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          notificationId: event.params.notificationId,
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

      const res = await admin.messaging().send(payload as any);
      logger.info(`Pushed notification ${event.params.notificationId} to ${userEmail}: ${res}`);
    } catch (e) {
      logger.error(`Error pushing notification ${event.params.notificationId}:`, e);
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
    const fcmToken = userData?.fcmToken;
    if (fcmToken) {
      logger.info(`User ${event.params.userId} deleted, FCM token was: ${fcmToken}`);
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
    if (beforeToken !== afterToken) {
      logger.info(`User ${event.params.userId} FCM token updated`);
      logger.info(`Old token: ${beforeToken || "none"}`);
      logger.info(`New token: ${afterToken || "none"}`);
    }
  }
);
