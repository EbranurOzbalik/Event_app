import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { BatchResponse, getMessaging, MulticastMessage } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";

if (!getApps().length) {
  initializeApp();
}

const db = getFirestore();
const messaging = getMessaging();
const ALL_USERS_TOPIC = "all_users";
const ANDROID_CHANNEL_ID = "event_app_default";

type PushPayload = {
  title: string;
  body: string;
  data: Record<string, string>;
};

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function compactData(data: Record<string, string>): Record<string, string> {
  const output: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    const normalized = value.trim();
    if (normalized.length > 0) {
      output[key] = normalized;
    }
  }
  return output;
}

function isTokenError(code: string): boolean {
  return (
    code === "messaging/invalid-registration-token" ||
    code === "messaging/registration-token-not-registered"
  );
}

async function readEventTitle(eventId: string): Promise<string> {
  if (eventId.length === 0) {
    return "";
  }

  const eventDoc = await db.collection("events").doc(eventId).get();
  return asString(eventDoc.data()?.title);
}

async function readUserTokens(uid: string): Promise<string[]> {
  if (uid.length === 0) {
    return [];
  }

  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.data();
  if (!userData) {
    return [];
  }

  const rawTokens = userData.fcmTokens;
  if (!Array.isArray(rawTokens)) {
    return [];
  }

  const normalized = rawTokens
    .map((token) => asString(token))
    .filter((token) => token.length > 0);

  return Array.from(new Set(normalized));
}

async function removeInvalidTokens(uid: string, invalidTokens: string[]): Promise<void> {
  if (uid.length === 0 || invalidTokens.length === 0) {
    return;
  }

  await db.collection("users").doc(uid).set(
    {
      fcmTokens: FieldValue.arrayRemove(...invalidTokens),
      lastFcmTokenUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function sendPushToUser(uid: string, payload: PushPayload): Promise<void> {
  const tokens = await readUserTokens(uid);
  if (tokens.length === 0) {
    logger.info("Push skipped because user has no FCM token.", { uid });
    return;
  }

  const message: MulticastMessage = {
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: compactData(payload.data),
    android: {
      priority: "high",
      notification: {
        channelId: ANDROID_CHANNEL_ID,
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  const response: BatchResponse = await messaging.sendEachForMulticast(message);
  logger.info("Push send result", {
    uid,
    successCount: response.successCount,
    failureCount: response.failureCount,
  });

  if (response.failureCount === 0) {
    return;
  }

  const invalidTokens: string[] = [];
  response.responses.forEach((entry, index) => {
    if (entry.success) {
      return;
    }
    const code = entry.error?.code ?? "";
    if (isTokenError(code)) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    await removeInvalidTokens(uid, invalidTokens);
  }
}

export const pushTicketReady = onDocumentCreated("registrations/{registrationId}", async (event) => {
  const registration = event.data?.data();
  if (!registration) {
    return;
  }

  const userId = asString(registration.userId);
  if (userId.length === 0) {
    return;
  }

  const eventId = asString(registration.eventId);
  let eventTitle = asString(registration.eventTitle);
  if (eventTitle.length === 0) {
    eventTitle = await readEventTitle(eventId);
  }
  if (eventTitle.length === 0) {
    eventTitle = "Etkinlik";
  }

  await sendPushToUser(userId, {
    title: "Biletin hazır",
    body: `${eventTitle} bileti oluşturuldu. Girişte QR okutabilirsin.`,
    data: {
      type: "ticket_ready",
      screen: "tickets",
      eventId,
      registrationId: asString(event.params.registrationId),
    },
  });
});

export const pushCheckInApproved = onDocumentUpdated("registrations/{registrationId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) {
    return;
  }

  const wasCheckedIn = before.checkedIn === true;
  const isCheckedIn = after.checkedIn === true;
  if (wasCheckedIn || !isCheckedIn) {
    return;
  }

  const userId = asString(after.userId);
  if (userId.length === 0) {
    return;
  }

  const eventId = asString(after.eventId);
  let eventTitle = asString(after.eventTitle);
  if (eventTitle.length === 0) {
    eventTitle = await readEventTitle(eventId);
  }
  if (eventTitle.length === 0) {
    eventTitle = "Etkinlik";
  }

  await sendPushToUser(userId, {
    title: "Giriş onaylandı",
    body: `${eventTitle} için girişin başarıyla tamamlandı.`,
    data: {
      type: "check_in_success",
      screen: "tickets",
      eventId,
      registrationId: asString(event.params.registrationId),
    },
  });
});

export const pushNewEvent = onDocumentCreated("events/{eventId}", async (event) => {
  const data = event.data?.data();
  if (!data) {
    return;
  }

  const eventId = asString(event.params.eventId);
  const eventTitle = asString(data.title) || "Yeni etkinlik";
  const eventDate = asString(data.date);
  const body = eventDate.length > 0 ? `${eventTitle} • ${eventDate}` : eventTitle;

  await messaging.send({
    topic: ALL_USERS_TOPIC,
    notification: {
      title: "Yeni etkinlik",
      body,
    },
    data: compactData({
      type: "new_event",
      screen: "discover",
      eventId,
      eventTitle,
      eventDate,
    }),
    android: {
      priority: "high",
      notification: {
        channelId: ANDROID_CHANNEL_ID,
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  });

  logger.info("Broadcast push sent for new event.", { eventId, eventTitle });
});
