/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {initializeApp} from "firebase-admin/app";
import {
  DocumentSnapshot,
  getFirestore,
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";

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

export const onChatMessageCreated = onDocumentCreated(
  "chat_rooms/{roomId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) return;

    const updates: Record<string, unknown> = {};
    if (messageData.read === undefined) {
      updates.read = false;
    }

    if (Object.keys(updates).length > 0) {
      await event.data?.ref.set(updates, {merge: true});
    }

    if (typeof messageData.message === "string") {
      const roomRef = db.collection("chat_rooms").doc(event.params.roomId);
      await roomRef.set(
        {
          lastMessage: messageData.message,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
  },
);

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
 * 옮길 때 문서 ID를 그대로 물려주기 때문에, 함수가 두 번 실행돼도
 * 같은 건이 두 개로 늘어나지 않는다.
 */

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
      // 이용중으로 전환된 시점
      createdAt: FieldValue.serverTimestamp(),
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

/**
 * 오늘부터 시작하는 예약이면 승인 즉시 이용 중으로 넘긴다.
 *
 * 미래 예약은 여기서 아무것도 하지 않고, 아래 스케줄러가 시작일에 처리한다.
 */
export const onReservationApproved = onDocumentUpdated(
  "reservations/{reservationId}",
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;

    const wasApproved = before.data()?.status === "approved";
    const isApproved = after.data()?.status === "approved";
    if (wasApproved || !isApproved) return;

    const startAt = after.data()?.startAt as Timestamp | undefined;
    if (!startAt || startAt.toMillis() > Date.now()) return;

    const activated = await activateReservation(after);
    if (activated) {
      logger.info(`Reservation ${event.params.reservationId} -> usage`);
    }
  },
);

/**
 * 매일 한국시간 0시 5분에 상태를 넘긴다.
 *  - 시작일이 된 예약 → 이용 중
 *  - 종료일이 지난 이용 → 이용 내역
 */
export const rolloverStorageUsages = onSchedule(
  {schedule: "5 0 * * *", timeZone: "Asia/Seoul"},
  async () => {
    const now = Timestamp.now();

    const dueReservations = await db
      .collection("reservations")
      .where("status", "==", "approved")
      .where("startAt", "<=", now)
      .get();

    let activated = 0;
    for (const doc of dueReservations.docs) {
      try {
        if (await activateReservation(doc)) activated += 1;
      } catch (error) {
        logger.error(`Failed to activate reservation ${doc.id}`, error);
      }
    }

    const expiredUsages = await db
      .collection("usages")
      .where("endAt", "<=", now)
      .get();

    let finished = 0;
    for (const doc of expiredUsages.docs) {
      try {
        if (await finishUsage(doc)) finished += 1;
      } catch (error) {
        logger.error(`Failed to finish usage ${doc.id}`, error);
      }
    }

    logger.info(
      `Rollover done: ${activated} activated, ${finished} finished`,
    );
  },
);

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
