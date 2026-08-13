/**
 * 지미커 Cloud Functions
 *
 * 모든 함수는 서울 리전(asia-northeast3)에서 돈다. 사용자가 국내에 있어
 * 지연이 짧고, 기존에 배포된 함수들도 같은 리전이라 하나로 맞춰둔다.
 */

import {logger, setGlobalOptions} from "firebase-functions/v2";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {initializeApp} from "firebase-admin/app";
import {
  DocumentSnapshot,
  getFirestore,
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";

setGlobalOptions({region: "asia-northeast3"});

initializeApp();
const db = getFirestore();

// storages/{locationId} 문서가 "업데이트"될 때마다 실행
export const onStorageApproved = onDocumentUpdated(
  "storages/{locationId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // approved가 실제로 바뀌었는지 체크 (false -> true 같은 경우만)
    if (before.approved === after.approved) return;
    if (after.approved !== true) return;

    const locationId = event.params.locationId;
    const ownerId = after.ownerId as string;

    const roomId = `system_${ownerId}`;
    const roomRef = db.collection("chat_rooms").doc(roomId);
    const messageRef = roomRef.collection("messages").doc();
    const message = `등록하신 창고(${locationId})가 승인되었습니다.`;

    await db.runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomRef);

      if (!roomSnapshot.exists) {
        transaction.set(roomRef, {
          roomName: "지미커(시스템)",
          participantUids: ["system", ownerId],
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.set(messageRef, {
        uid: "system",
        displayName: "지미커(시스템)",
        message,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });

      transaction.set(
        roomRef,
        {
          lastMessage: message,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });
  },
);

/**
 * 채팅 목록에 보여줄 미리보기 문구. 사진만 보낸 경우도 처리한다.
 * @param {FirebaseFirestore.DocumentData} data 메시지 문서
 * @return {string} 목록과 알림에 쓸 한 줄
 */
function messagePreview(data: FirebaseFirestore.DocumentData): string {
  const text = typeof data.message === "string" ? data.message.trim() : "";
  if (text.length > 0) return text;
  return data.imageUrl ? "사진" : "";
}

export const onChatMessageCreated = onDocumentCreated(
  "chat_rooms/{roomId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) return;

    if (messageData.read === undefined) {
      await event.data?.ref.set({read: false}, {merge: true});
    }

    const roomRef = db.collection("chat_rooms").doc(event.params.roomId);
    await roomRef.set(
      {
        lastMessage: messagePreview(messageData),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  },
);

/**
 * 새 메시지가 오면 상대에게 푸시 알림을 보낸다.
 *
 * 목록 갱신(onChatMessageCreated)과 나눠둔 이유: 알림 전송이 실패해도
 * lastMessage 갱신은 영향받지 않아야 하기 때문이다.
 */
export const sendChatNotification = onDocumentCreated(
  "chat_rooms/{roomId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) return;

    const roomId = event.params.roomId;
    const senderUid = messageData.uid as string | undefined;
    if (!senderUid) return;

    const roomSnapshot = await db.collection("chat_rooms").doc(roomId).get();
    const participantUids = roomSnapshot.data()?.participantUids as
      | string[]
      | undefined;

    if (!participantUids) {
      logger.warn(`No participants for room ${roomId}`);
      return;
    }

    // 보낸 사람과 시스템 계정을 뺀 나머지가 받는 사람이다.
    const receivers = participantUids.filter(
      (uid) => uid !== senderUid && uid !== "system",
    );
    if (receivers.length === 0) return;

    const body = messagePreview(messageData);
    const title =
      (messageData.displayName as string | undefined) ?? "새 메시지";

    await Promise.all(
      receivers.map((uid) => notifyUser(uid, title, body, roomId)),
    );
  },
);

/**
 * 한 사람에게 채팅 알림을 보낸다.
 * @param {string} uid 받는 사람
 * @param {string} title 알림 제목(보낸 사람 이름)
 * @param {string} body 알림 본문
 * @param {string} roomId 눌렀을 때 열 채팅방
 * @return {Promise<void>}
 */
async function notifyUser(
  uid: string,
  title: string,
  body: string,
  roomId: string,
): Promise<void> {
  const userRef = db.collection("users").doc(uid);
  const fcmToken = (await userRef.get()).data()?.fcmToken as
    | string
    | undefined;

  if (!fcmToken) return;

  try {
    await getMessaging().send({
      token: fcmToken,
      notification: {title, body},
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        payload: {aps: {sound: "default"}},
      },
      data: {
        roomId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    });
  } catch (error) {
    const code = (error as {code?: string}).code;

    // 앱을 지웠거나 토큰이 만료된 경우. 남겨두면 계속 실패하므로 비운다.
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      await userRef.set({fcmToken: ""}, {merge: true});
      logger.info(`Cleared stale fcmToken for ${uid}`);
      return;
    }

    logger.error(`Failed to notify ${uid}`, error);
  }
}

/**
 * ─────────────────────────────────────────────────────────────
 * 예약 → 이용 중 → 이용 내역 흐름
 * ─────────────────────────────────────────────────────────────
 *
 * reservations  주인의 승인을 기다리거나, 승인됐지만 아직 시작 전인 건
 * usages        시작일이 되어 실제로 쓰고 있는 건
 * endeds        종료일이 지난 건
 *
 * 승인하는 순간 바로 usages로 넘기지 않는 이유:
 * 예약은 "다음 달부터 쓰겠다"처럼 미래를 잡아두는 것이라, 승인 즉시 이용 중이 되면
 * 아직 시작도 안 한 건이 '이용 중인 창고'에 뜬다. 또 확정된 예약을 취소 요청하는
 * 화면도 볼 수 없게 된다. 그래서 시작일이 실제로 도래했을 때 옮긴다.
 *
 * 옮길 때 문서 ID를 그대로 물려주고 트랜잭션 안에서 대상이 이미 있는지 확인한다.
 * 스케줄러가 겹쳐 돌거나 재시도돼도 같은 건이 두 개로 늘어나지 않는다.
 */

/** 한 번에 처리할 문서 수. 남은 건은 다음 실행에서 이어서 처리한다. */
const MIGRATION_BATCH_SIZE = 200;

/**
 * 승인됐고 시작일이 지난 예약을 usages로 옮긴다.
 * @param {DocumentSnapshot} snapshot 옮길 예약 문서
 * @return {Promise<boolean>} 이번 호출에서 실제로 옮겼으면 true
 */
async function activateReservation(
  snapshot: DocumentSnapshot,
): Promise<boolean> {
  const reservationRef = snapshot.ref;
  const usageRef = db.collection("usages").doc(snapshot.id);

  return db.runTransaction(async (transaction) => {
    const [reservation, usage] = await Promise.all([
      transaction.get(reservationRef),
      transaction.get(usageRef),
    ]);

    // 이미 다른 실행이 처리했다면 조용히 끝낸다.
    if (!reservation.exists) return false;
    if (usage.exists) {
      transaction.delete(reservationRef);
      return false;
    }

    const data = reservation.data();
    if (!data || data.status !== "approved") return false;

    transaction.set(usageRef, {
      userId: data.userId,
      ownerId: data.ownerId,
      storageId: data.storageId,
      containerIndex: data.containerIndex,
      startAt: data.startAt,
      endAt: data.endAt,
      // 예약을 신청한 시점. 언제 신청했는지가 화면에 필요하다.
      createdAt: data.createdAt,
      // 이용 중으로 전환된 시점
      activatedAt: FieldValue.serverTimestamp(),
    });
    transaction.delete(reservationRef);
    return true;
  });
}

/**
 * 종료일이 지난 이용을 endeds로 옮긴다.
 * @param {DocumentSnapshot} snapshot 옮길 이용 문서
 * @return {Promise<boolean>} 이번 호출에서 실제로 옮겼으면 true
 */
async function finishUsage(snapshot: DocumentSnapshot): Promise<boolean> {
  const usageRef = snapshot.ref;
  const endedRef = db.collection("endeds").doc(snapshot.id);

  return db.runTransaction(async (transaction) => {
    const [usage, ended] = await Promise.all([
      transaction.get(usageRef),
      transaction.get(endedRef),
    ]);

    if (!usage.exists) return false;
    if (ended.exists) {
      transaction.delete(usageRef);
      return false;
    }

    const data = usage.data();
    if (!data) return false;

    transaction.set(endedRef, {
      ...data,
      finishedAt: FieldValue.serverTimestamp(),
    });
    transaction.delete(usageRef);
    return true;
  });
}

/** 시작일이 된 예약을 이용 중으로 옮긴다. (1분마다) */
export const migrateActiveReservations = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Seoul",
    timeoutSeconds: 120,
  },
  async () => {
    const snapshot = await db
      .collection("reservations")
      .where("status", "==", "approved")
      .where("startAt", "<=", Timestamp.now())
      .limit(MIGRATION_BATCH_SIZE)
      .get();

    if (snapshot.empty) return;

    let moved = 0;
    for (const doc of snapshot.docs) {
      try {
        if (await activateReservation(doc)) moved += 1;
      } catch (error) {
        logger.error(`Failed to activate reservation ${doc.id}`, error);
      }
    }

    if (moved > 0) logger.info(`${moved}개의 예약이 이용 중으로 넘어갔습니다.`);
  },
);

/** 종료일이 지난 이용을 이용 내역으로 옮긴다. (1분마다) */
export const migrateFinishedUsages = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Seoul",
    timeoutSeconds: 120,
  },
  async () => {
    const snapshot = await db
      .collection("usages")
      .where("endAt", "<=", Timestamp.now())
      .limit(MIGRATION_BATCH_SIZE)
      .get();

    if (snapshot.empty) return;

    let moved = 0;
    for (const doc of snapshot.docs) {
      try {
        if (await finishUsage(doc)) moved += 1;
      } catch (error) {
        logger.error(`Failed to finish usage ${doc.id}`, error);
      }
    }

    if (moved > 0) logger.info(`${moved}개의 이용이 종료 처리되었습니다.`);
  },
);
