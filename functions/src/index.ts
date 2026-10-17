import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * Calculates great-circle distance between two coordinates in meters
 * using the Haversine formula.
 */
function haversineDistanceMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371e3; // Earth radius in meters
  const toRad = (deg: number) => (deg * Math.PI) / 180;

  const φ1 = toRad(lat1);
  const φ2 = toRad(lat2);
  const Δφ = toRad(lat2 - lat1);
  const Δλ = toRad(lon2 - lon1);

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Cloud Function Trigger: onDocumentCreated("items/{itemId}")
 *
 * Automatically triggers whenever a new item is posted.
 * Queries opposite-type items in the same category within 500m from the last 7 days,
 * and sends an FCM push notification to the owner of matching items.
 */
export const onNewItemSmartMatch = onDocumentCreated(
  "items/{itemId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn("No data associated with the event.");
      return;
    }

    const newItem = snap.data();
    const newItemId = event.params.itemId;

    const {
      type,
      category,
      title,
      location,
      ownerId,
      createdAt,
    } = newItem;

    if (!type || !category || !location || !location.latitude || !location.longitude) {
      logger.info(`Item ${newItemId} missing required fields for smart matching.`);
      return;
    }

    const oppositeType = type === "lost" ? "found" : "lost";
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    logger.info(
      `Running Smart Match for ${type} item (${newItemId}, category: ${category}) looking for ${oppositeType} within 500m...`
    );

    try {
      // 1. Query opposite type in same category from last 7 days
      const candidatesSnapshot = await db
        .collection("items")
        .where("type", "==", oppositeType)
        .where("category", "==", category)
        .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
        .get();

      if (candidatesSnapshot.empty) {
        logger.info(`No candidate ${oppositeType} items found in ${category} over the last 7 days.`);
        return;
      }

      logger.info(`Found ${candidatesSnapshot.docs.length} candidates in category. Checking 500m radius...`);

      const matchingCandidates: admin.firestore.QueryDocumentSnapshot[] = [];

      for (const doc of candidatesSnapshot.docs) {
        if (doc.id === newItemId) continue;
        const candidateData = doc.data();

        if (
          !candidateData.location ||
          candidateData.location.latitude == null ||
          candidateData.location.longitude == null
        ) {
          continue;
        }

        const distanceMeters = haversineDistanceMeters(
          location.latitude,
          location.longitude,
          candidateData.location.latitude,
          candidateData.location.longitude
        );

        if (distanceMeters <= 500) {
          logger.info(
            `Match found! Item ${doc.id} ("${candidateData.title}") is ~${Math.round(distanceMeters)}m away.`
          );
          matchingCandidates.push(doc);

          // 2. Look up the candidate owner's FCM token to dispatch push notification
          const candidateOwnerId = candidateData.ownerId;
          if (candidateOwnerId && candidateOwnerId !== ownerId) {
            const userDoc = await db.collection("users").doc(candidateOwnerId).get();
            const fcmToken = userDoc.data()?.fcmToken;

            if (fcmToken) {
              const notificationTitle = `✨ Possible Match for your ${oppositeType.toUpperCase()} item!`;
              const notificationBody = `A matching ${category} item ("${title}") was reported near ${location.label || "Campus"} (~${Math.round(distanceMeters)}m away). Tap to check!`;

              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: notificationTitle,
                  body: notificationBody,
                },
                data: {
                  type: "smart_match",
                  itemId: newItemId,
                  matchedItemId: doc.id,
                  category: category,
                },
                android: {
                  priority: "high",
                  notification: {
                    channelId: "finders_keepers_matches",
                    icon: "ic_notification",
                    color: "#00897B",
                  },
                },
              });

              logger.info(`Dispatched FCM notification to user ${candidateOwnerId}`);
            }
          }
        }
      }

      logger.info(
        `Smart Match completed for ${newItemId}: ${matchingCandidates.length} matches within 500m.`
      );
    } catch (error) {
      logger.error("Error executing onNewItemSmartMatch Cloud Function:", error);
    }
  }
);
