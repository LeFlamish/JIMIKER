/**
 * 지미커 Cloud Functions
 *
 * 모든 함수는 서울 리전(asia-northeast3)에서 돈다. 사용자가 국내에 있어
 * 지연이 짧고, 기존에 배포된 함수들도 같은 리전이라 하나로 맞춰둔다.
 *
 * ── 배포 주의 ──────────────────────────────────────────────
 * firebase.json의 functions.predeploy(npm install + npm run build)를
 * 절대 지우지 말 것.
 *
 * firebase CLI는 package.json의 main(= lib/index.js)을 "로컬에서" 읽어
 * 무엇을 배포할지 정한다. 컴파일 결과물인 lib/이 낡아 있으면 새로 만든
 * 함수가 목록에 안 잡히고, 그런데도 배포는 오류 없이 성공한다.
 * 그러면 콘솔에는 옛 함수만 남고 앱에서는 NOT_FOUND가 난다.
 *
 * package.json의 gcp-build도 tsc를 돌리지만 그건 Cloud Build 안에서,
 * 즉 CLI가 목록을 정한 "뒤"라 이 문제를 막지 못한다.
 * ───────────────────────────────────────────────────────────
 */

import {logger, setGlobalOptions} from "firebase-functions/v2";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {initializeApp} from "firebase-admin/app";
import {
  DocumentSnapshot,
  QueryDocumentSnapshot,
  getFirestore,
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getStorage} from "firebase-admin/storage";

setGlobalOptions({region: "asia-northeast3"});

initializeApp();
const db = getFirestore();

// 장소 검색용 Places API 키. 앱에 넣지 않고 서버 시크릿으로만 보관한다.
// 배포 전에 한 번: firebase functions:secrets:set PLACES_API_KEY
const placesApiKey = defineSecret("PLACES_API_KEY");

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
          // 알림 방을 나갔던 사용자도 새 알림이 오면 다시 참여자가 된다.
          participantUids: FieldValue.arrayUnion("system", ownerId),
          leftUids: FieldValue.arrayRemove(ownerId),
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

    // 목록에 띄울 안 읽은 수. 받는 사람 것만 하나 올린다.
    // 세는 일을 앱에서 하면 방 개수만큼 쿼리가 나가고, 앱을 고쳐서
    // 남의 것을 건드릴 수도 있다. 서버가 세고 앱은 자기 것만 0으로 되돌린다.
    const senderUid = messageData.uid as string | undefined;
    const participantUids = (await roomRef.get()).data()
      ?.participantUids as string[] | undefined;

    const unreadCounts: Record<string, FirebaseFirestore.FieldValue> = {};
    for (const uid of participantUids ?? []) {
      if (uid === senderUid || uid === "system") continue;
      unreadCounts[uid] = FieldValue.increment(1);
    }

    await roomRef.set(
      {
        lastMessage: messagePreview(messageData),
        updatedAt: FieldValue.serverTimestamp(),
        ...(Object.keys(unreadCounts).length > 0 ? {unreadCounts} : {}),
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
 * 예약 생성
 * ─────────────────────────────────────────────────────────────
 *
 * 앱에서 바로 reservations 문서를 쓰지 않고 여기를 거친다. 두 가지 때문이다.
 *
 * 1. 기간 겹침은 보안 규칙으로 막을 수 없다.
 *    규칙은 다른 문서를 "범위로" 훑어볼 수 없어서, 이미 잡힌 예약과
 *    겹치는지 확인할 방법이 없다. 앱에서만 확인하면 두 사람이 같은 순간에
 *    누를 때 둘 다 성공한다.
 *
 * 2. 계약 금액을 그 시점 값으로 박아둬야 한다.
 *    금액을 안 남기면 화면이 창고의 "지금" 가격을 읽어오는데, 주인이 나중에
 *    올리면 작년에 끝난 이용 내역의 금액까지 바뀐다. 분쟁 때 근거가 없다.
 */

/** 예약 한 건에 허용하는 최대 개월 수 */
const MAX_RESERVATION_MONTHS = 24;

/**
 * 시작일에 개월 수를 더한다. (예약 종료일)
 *
 * 말일 처리에 주의한다. 1월 31일 + 1개월을 그냥 두면 3월 3일이 되어버린다.
 * 그 달에 없는 날짜면 말일로 맞춘다.
 * @param {Date} start 시작일
 * @param {number} months 개월 수
 * @return {Date} 종료일
 */
function addMonths(start: Date, months: number): Date {
  const end = new Date(start.getTime());
  const day = end.getUTCDate();

  end.setUTCDate(1);
  end.setUTCMonth(end.getUTCMonth() + months);

  const lastDay = new Date(
    Date.UTC(end.getUTCFullYear(), end.getUTCMonth() + 1, 0),
  ).getUTCDate();
  end.setUTCDate(Math.min(day, lastDay));

  return end;
}

/**
 * 두 기간이 겹치는지.
 *
 * 한쪽이 끝나는 날에 다른 쪽이 시작하는 것은 겹침이 아니다.
 * (3월 1일에 끝나고 3월 1일에 시작하는 예약은 나란히 붙을 수 있다)
 * @param {Date} aStart 이번 예약 시작
 * @param {Date} aEnd 이번 예약 종료
 * @param {Date} bStart 이미 잡힌 예약 시작
 * @param {Date} bEnd 이미 잡힌 예약 종료
 * @return {boolean} 겹치면 true
 */
function overlaps(
  aStart: Date, aEnd: Date, bStart: Date, bEnd: Date,
): boolean {
  return aStart < bEnd && aEnd > bStart;
}

/**
 * 예약을 만든다.
 *
 * 같은 구역·같은 기간이 이미 잡혀 있으면 거절한다. 확인과 생성을 한
 * 트랜잭션에 넣고, 구역 문서를 같이 건드려서 동시에 들어온 요청 중
 * 하나만 통과하게 한다.
 */
export const createReservation = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }

  const storageId = String(request.data?.storageId ?? "");
  const containerIndex = String(request.data?.containerIndex ?? "");
  const startAtMs = Number(request.data?.startAtMs);
  const months = Math.trunc(Number(request.data?.months));

  if (!storageId || !containerIndex) {
    throw new HttpsError("invalid-argument", "예약할 구역을 선택해주세요.");
  }
  if (!Number.isFinite(startAtMs)) {
    throw new HttpsError("invalid-argument", "시작 날짜를 선택해주세요.");
  }
  if (!(months >= 1 && months <= MAX_RESERVATION_MONTHS)) {
    throw new HttpsError(
      "invalid-argument",
      `이용 기간은 1개월부터 ${MAX_RESERVATION_MONTHS}개월까지 고를 수 있어요.`,
    );
  }

  // 날짜만 쓰므로 시각은 잘라낸다. 기기 시계가 조금 달라도 같은 날이 된다.
  const startAt = new Date(startAtMs);
  startAt.setUTCHours(0, 0, 0, 0);
  const endAt = addMonths(startAt, months);

  // 지난 날짜로는 잡을 수 없다. 시차와 시계 오차를 감안해 하루 여유를 준다.
  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
  if (startAt < yesterday) {
    throw new HttpsError("invalid-argument", "지난 날짜로는 예약할 수 없어요.");
  }

  const [userSnapshot, storageSnapshot] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("storages").doc(storageId).get(),
  ]);

  if (userSnapshot.data()?.suspended === true) {
    throw new HttpsError(
      "permission-denied",
      "이용이 정지된 계정입니다. 문의해주세요.",
    );
  }

  const storage = storageSnapshot.data();
  if (!storageSnapshot.exists || !storage) {
    throw new HttpsError("not-found", "창고를 찾을 수 없습니다.");
  }
  if (storage.approved !== true || storage.deleted === true) {
    throw new HttpsError(
      "failed-precondition",
      "지금은 예약할 수 없는 창고입니다.",
    );
  }

  const ownerId = String(storage.ownerId ?? "");
  if (!ownerId) {
    throw new HttpsError("failed-precondition", "창고 정보가 올바르지 않아요.");
  }
  if (ownerId === uid) {
    throw new HttpsError(
      "failed-precondition",
      "내가 등록한 창고는 예약할 수 없어요.",
    );
  }

  const storageRef = db.collection("storages").doc(storageId);
  const zoneRef = storageRef.collection("zones").doc(containerIndex);
  const reservationRef = db.collection("reservations").doc();

  const startTs = Timestamp.fromDate(startAt);
  const endTs = Timestamp.fromDate(endAt);

  const result = await db.runTransaction(async (transaction) => {
    // 겹치는지 볼 때는 예약과 이용 중을 모두 본다.
    // 시작일이 지나면 예약이 usages로 옮겨가기 때문에 한쪽만 보면 샌다.
    const taken = (collection: string) =>
      transaction.get(
        db
          .collection(collection)
          .where("storageId", "==", storageId)
          .where("containerIndex", "==", containerIndex),
      );

    const [zone, reservations, usages] = await Promise.all([
      transaction.get(zoneRef),
      taken("reservations"),
      taken("usages"),
    ]);

    const zoneData = zone.data();
    if (!zone.exists || !zoneData) {
      throw new HttpsError("not-found", "구역을 찾을 수 없습니다.");
    }

    const monthlyPrice = Number(zoneData.price);
    if (!Number.isFinite(monthlyPrice) || monthlyPrice < 0) {
      throw new HttpsError(
        "failed-precondition",
        "구역 가격이 설정되지 않았어요. 주인에게 문의해주세요.",
      );
    }

    const busy = [
      // 거절된 예약은 자리를 비워둔 것이므로 겹침에서 뺀다.
      ...reservations.docs.filter((doc) => doc.data().status !== "rejected"),
      ...usages.docs,
    ];

    for (const doc of busy) {
      const data = doc.data();
      const otherStart = (data.startAt as Timestamp | undefined)?.toDate();
      const otherEnd = (data.endAt as Timestamp | undefined)?.toDate();
      if (!otherStart || !otherEnd) continue;

      if (overlaps(startAt, endAt, otherStart, otherEnd)) {
        throw new HttpsError(
          "already-exists",
          "그 기간에는 이미 예약이 있어요. 다른 날짜를 골라주세요.",
        );
      }
    }

    // 구역 문서를 같이 건드려서 같은 구역에 동시에 들어온 요청을 줄 세운다.
    // 이게 없으면 두 트랜잭션이 서로의 예약을 못 보고 둘 다 통과할 수 있다.
    transaction.set(
      zoneRef,
      {lastReservedAt: FieldValue.serverTimestamp()},
      {merge: true},
    );

    transaction.set(reservationRef, {
      userId: uid,
      ownerId,
      storageId,
      containerIndex,
      startAt: startTs,
      endAt: endTs,
      status: "waiting",
      createdAt: FieldValue.serverTimestamp(),
      // 계약한 금액. 주인이 나중에 가격을 바꿔도 이 값은 그대로 남는다.
      monthlyPrice,
      months,
      totalPrice: monthlyPrice * months,
    });

    return {monthlyPrice, totalPrice: monthlyPrice * months};
  });

  return {
    reservationId: reservationRef.id,
    ownerId,
    months,
    ...result,
  };
});

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
      // 계약 금액. 예약할 때 박아둔 값을 그대로 물려준다.
      // 여기서 다시 구역 가격을 읽으면 그 사이 주인이 바꾼 값이 들어간다.
      ...(data.monthlyPrice === undefined ?
        {} :
        {
          monthlyPrice: data.monthlyPrice,
          months: data.months,
          totalPrice: data.totalPrice,
        }),
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

/**
 * ─────────────────────────────────────────────────────────────
 * 관리자(매니저) 기능
 * ─────────────────────────────────────────────────────────────
 *
 * 승인·반려·정지는 모두 여기서 처리한다. 보안 규칙에는 매니저 쓰기 권한을
 * 아예 넣지 않는다. 앱을 뜯어 고쳐도 남의 창고를 승인할 수 없고,
 * 나중에 웹 관리자 화면을 붙일 때도 이 함수를 그대로 부르면 된다.
 */

/**
 * 호출자가 매니저인지 확인한다.
 * @param {string | undefined} uid 호출자 uid
 * @return {Promise<string>} 확인된 매니저 uid
 */
async function requireManager(uid: string | undefined): Promise<string> {
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }

  const snapshot = await db.collection("users").doc(uid).get();
  if (snapshot.data()?.userType !== "manager") {
    throw new HttpsError("permission-denied", "관리자만 할 수 있습니다.");
  }
  return uid;
}

/**
 * 관리자 조치를 기록한다. 매니저가 여러 명이 되면
 * "누가 이걸 반려했지?"에 답할 수 있어야 한다.
 * @param {string} actorUid 조치한 매니저
 * @param {string} action 조치 종류
 * @param {string} targetId 대상 문서 id
 * @param {Record<string, unknown>} extra 사유 등 부가 정보
 * @return {Promise<void>}
 */
async function writeAdminLog(
  actorUid: string,
  action: string,
  targetId: string,
  extra: Record<string, unknown> = {},
): Promise<void> {
  await db.collection("admin_logs").add({
    actorUid,
    action,
    targetId,
    ...extra,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * 시스템 채팅방으로 알림 메시지를 보낸다.
 * @param {string} uid 받는 사람
 * @param {string} message 보낼 문구
 * @return {Promise<void>}
 */
async function sendSystemMessage(
  uid: string,
  message: string,
): Promise<void> {
  const roomRef = db.collection("chat_rooms").doc(`system_${uid}`);
  const messageRef = roomRef.collection("messages").doc();

  await db.runTransaction(async (transaction) => {
    const room = await transaction.get(roomRef);

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
        roomName: "지미커(시스템)",
        participantUids: ["system", uid],
        // 알림 방을 나갔던 사용자도 새 알림이 오면 다시 참여자가 된다.
        // (예약 승인 같은 중요한 안내를 놓치면 안 되기 때문)
        leftUids: FieldValue.arrayRemove(uid),
        lastMessage: message,
        updatedAt: FieldValue.serverTimestamp(),
        ...(room.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      },
      {merge: true},
    );
  });
}

/**
 * ─────────────────────────────────────────────────────────────
 * 승인된 창고를 반려로 되돌릴 때의 뒷정리
 * ─────────────────────────────────────────────────────────────
 *
 * 이미 짐을 넣고 쓰고 있는 사람(usages)과, 아직 시작 전인 예약(reservations)은
 * 처지가 다르다.
 *
 *  - 이용 중  : 손대지 않는다. 물건이 안에 들어 있는데 관리자 판단으로
 *               계약을 끊으면 이용자가 갈 곳이 없다. 기간이 끝나면
 *               migrateFinishedUsages가 평소대로 이용 내역으로 넘긴다.
 *  - 예약     : 취소한다. 반려된 창고는 지도·목록에서 사라져서 이용자가
 *               상세를 다시 볼 수도 없고, 시작일이 되면 이용 중으로
 *               넘어가버리기 때문에 그냥 두면 안 된다.
 *
 * 새 예약이 더 들어오는 것은 보안 규칙(storageIsOpen)이 막는다.
 */

/** 한 번에 읽어올 예약 수. 다 처리할 때까지 페이지를 넘긴다. */
const CASCADE_PAGE_SIZE = 300;

/** 창고 반려로 무엇이 영향받았는지 */
interface RejectImpact {
  /** 취소된 예약 건수 */
  cancelledReservations: number;
  /** 그대로 유지한 이용 중 건수 */
  keptUsages: number;
}

/**
 * 한 창고에 걸린 예약을 페이지 단위로 훑는다.
 *
 * storageId 하나로만 거르고 정렬은 문서 id로 한다. 자동 색인만으로 돌아가서
 * 색인을 따로 만들 필요가 없다. (status까지 쿼리로 거르면 복합 색인이 필요하고,
 * != 조건은 필드가 아예 없는 옛 문서를 빼먹는다.)
 * @param {string} storageId 대상 창고
 * @param {Function} handle 한 페이지를 받아 처리하는 함수
 * @return {Promise<void>}
 */
async function forEachReservationOfStorage(
  storageId: string,
  handle: (docs: QueryDocumentSnapshot[]) => Promise<void>,
): Promise<void> {
  let cursor: QueryDocumentSnapshot | undefined;

  for (;;) {
    let query = db
      .collection("reservations")
      .where("storageId", "==", storageId)
      .orderBy("__name__")
      .limit(CASCADE_PAGE_SIZE);

    if (cursor) query = query.startAfter(cursor);

    const snapshot = await query.get();
    if (snapshot.empty) return;

    await handle(snapshot.docs);

    if (snapshot.size < CASCADE_PAGE_SIZE) return;
    cursor = snapshot.docs[snapshot.size - 1];
  }
}

/**
 * 창고에 남아 있는 예약을 모두 취소한다. (심사 반려·삭제 승인 공용)
 * @param {string} storageId 대상 창고
 * @param {string} notice 예약자에게 보낼 안내 문구
 * @return {Promise<number>} 취소한 예약 수
 */
async function cancelReservationsForStorage(
  storageId: string,
  notice: string =
  "예약하신 창고가 관리자 심사에서 반려되어 예약이 취소되었습니다.\n" +
  "결제 전이라 청구되는 금액은 없습니다. 다른 창고를 찾아주세요.",
): Promise<number> {
  let cancelled = 0;
  // 한 사람이 여러 구역을 잡아뒀어도 안내는 한 번만 보낸다.
  const affectedUsers = new Set<string>();

  await forEachReservationOfStorage(storageId, async (docs) => {
    const targets = docs.filter((doc) => doc.data().status !== "rejected");
    if (targets.length === 0) return;

    const batch = db.batch();
    for (const doc of targets) {
      batch.set(
        doc.ref,
        {
          status: "rejected",
          // 주인이 거절한 것과 구분하려고 남긴다.
          rejectedBy: "system",
          rejectedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      const userId = doc.data().userId;
      if (typeof userId === "string" && userId) affectedUsers.add(userId);
    }

    await batch.commit();
    cancelled += targets.length;
  });

  // 심사 사유는 등록자에게 쓴 내부 메모라 이용자에게는 옮기지 않는다.
  for (const uid of affectedUsers) {
    await sendSystemMessage(uid, notice);
  }

  return cancelled;
}

/**
 * 창고에 걸린 이용 중 건수를 센다. (내용은 건드리지 않는다)
 * @param {string} storageId 대상 창고
 * @return {Promise<number>} 이용 중 건수
 */
async function countUsagesForStorage(storageId: string): Promise<number> {
  const snapshot = await db
    .collection("usages")
    .where("storageId", "==", storageId)
    .count()
    .get();
  return snapshot.data().count;
}

/** 창고를 승인한다. 등록자 알림은 onStorageApproved가 이어서 보낸다. */
export const approveStorage = onCall(async (request) => {
  const managerUid = await requireManager(request.auth?.uid);
  const storageId = String(request.data?.storageId ?? "");

  if (!storageId) {
    throw new HttpsError("invalid-argument", "창고를 찾을 수 없습니다.");
  }

  const storageRef = db.collection("storages").doc(storageId);
  if (!(await storageRef.get()).exists) {
    throw new HttpsError("not-found", "창고를 찾을 수 없습니다.");
  }

  await storageRef.set(
    {
      approved: true,
      reviewStatus: "approved",
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedBy: managerUid,
      rejectReason: "",
    },
    {merge: true},
  );

  await writeAdminLog(managerUid, "approveStorage", storageId);
  return {ok: true};
});

/**
 * 창고를 반려한다. 사유를 등록자에게 그대로 전달하고,
 * 이미 승인돼 있던 창고라면 걸려 있는 예약까지 정리한다.
 */
export const rejectStorage = onCall(async (request) => {
  const managerUid = await requireManager(request.auth?.uid);
  const storageId = String(request.data?.storageId ?? "");
  const reason = String(request.data?.reason ?? "").trim();

  if (!storageId) {
    throw new HttpsError("invalid-argument", "창고를 찾을 수 없습니다.");
  }
  if (!reason) {
    throw new HttpsError("invalid-argument", "반려 사유를 적어주세요.");
  }

  const storageRef = db.collection("storages").doc(storageId);
  const snapshot = await storageRef.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "창고를 찾을 수 없습니다.");
  }

  // 먼저 노출을 끊는다. 뒷정리 중에 새 예약이 들어오면 안 된다.
  // (보안 규칙이 approved == false인 창고의 예약 생성을 막아준다.)
  await storageRef.set(
    {
      approved: false,
      reviewStatus: "rejected",
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedBy: managerUid,
      rejectReason: reason,
    },
    {merge: true},
  );

  const impact: RejectImpact = {
    cancelledReservations: await cancelReservationsForStorage(storageId),
    keptUsages: await countUsagesForStorage(storageId),
  };

  const ownerId = snapshot.data()?.ownerId as string | undefined;
  if (ownerId) {
    const lines = ["등록하신 창고가 반려되었습니다.", `사유: ${reason}`];

    if (impact.cancelledReservations > 0) {
      lines.push(
        `아직 시작하지 않은 예약 ${impact.cancelledReservations}건이 함께 취소되었습니다.`,
      );
    }
    if (impact.keptUsages > 0) {
      lines.push(
        `이미 이용 중인 ${impact.keptUsages}건은 기간이 끝날 때까지 그대로 유지됩니다.`,
      );
    }

    await sendSystemMessage(ownerId, lines.join("\n"));
  }

  await writeAdminLog(managerUid, "rejectStorage", storageId, {
    reason,
    ...impact,
  });
  return {ok: true, ...impact};
});

/** 사용자 이용을 정지하거나 해제한다. */
export const setUserSuspended = onCall(async (request) => {
  const managerUid = await requireManager(request.auth?.uid);
  const targetUid = String(request.data?.uid ?? "");
  const suspended = request.data?.suspended === true;
  const reason = String(request.data?.reason ?? "").trim();

  if (!targetUid) {
    throw new HttpsError("invalid-argument", "사용자를 찾을 수 없습니다.");
  }
  if (targetUid === managerUid) {
    throw new HttpsError("invalid-argument", "자기 계정은 정지할 수 없습니다.");
  }
  if (suspended && !reason) {
    throw new HttpsError("invalid-argument", "정지 사유를 적어주세요.");
  }

  const userRef = db.collection("users").doc(targetUid);
  const snapshot = await userRef.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "사용자를 찾을 수 없습니다.");
  }
  if (snapshot.data()?.userType === "manager") {
    throw new HttpsError("permission-denied", "관리자는 정지할 수 없습니다.");
  }

  await userRef.set(
    {
      suspended,
      suspendedAt: suspended ? FieldValue.serverTimestamp() : null,
      suspendReason: suspended ? reason : "",
    },
    {merge: true},
  );

  await sendSystemMessage(
    targetUid,
    suspended ?
      `계정 이용이 정지되었습니다.\n사유: ${reason}` :
      "계정 이용 정지가 해제되었습니다.",
  );

  await writeAdminLog(
    managerUid,
    suspended ? "suspendUser" : "unsuspendUser",
    targetUid,
    {reason},
  );
  return {ok: true};
});

/**
 * ─────────────────────────────────────────────────────────────
 * 창고 삭제 승인 절차
 * ─────────────────────────────────────────────────────────────
 *
 * 주인은 창고를 직접 지울 수 없다. (보안 규칙이 delete를 막는다)
 * 문서에 deleteRequested만 표시해 두면 운영자가 여기서 검토한다.
 * 예약이 걸린 창고를 주인이 말없이 없애버리는 일을 막기 위해서다.
 *
 * 승인해도 무조건 다 지우지는 않는다.
 *  - 이용 중이 있으면: 승인 자체를 거부한다. 짐이 들어 있는 계약을
 *    운영자 판단으로 끊을 수 없다. 기간이 끝난 뒤 다시 처리한다.
 *  - 시작 전 예약: 취소하고 예약자에게 안내한다.
 *  - 지난 기록(이용 내역·예약 이력)이 참조하면: 문서는 남기고
 *    deleted 표시만 한다. 기록이 전혀 없으면 사진까지 완전히 지운다.
 */
export const approveStorageDeletion = onCall(async (request) => {
  const managerUid = await requireManager(request.auth?.uid);
  const storageId = String(request.data?.storageId ?? "");

  if (!storageId) {
    throw new HttpsError("invalid-argument", "창고를 찾을 수 없습니다.");
  }

  const storageRef = db.collection("storages").doc(storageId);
  const snapshot = await storageRef.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "창고를 찾을 수 없습니다.");
  }
  if (snapshot.data()?.deleteRequested !== true) {
    throw new HttpsError(
      "failed-precondition",
      "주인이 삭제를 요청한 창고가 아닙니다.",
    );
  }

  // 짐이 들어 있는 계약은 운영자도 끊지 않는다.
  const activeUsages = await countUsagesForStorage(storageId);
  if (activeUsages > 0) {
    throw new HttpsError(
      "failed-precondition",
      `아직 이용 중인 계약이 ${activeUsages}건 있어요.\n` +
        "기간이 끝난 뒤 처리하거나, 반려로 사유를 알려주세요.",
    );
  }

  // 먼저 노출을 끊는다. 뒷정리 중에 새 예약이 들어오면 안 된다.
  await storageRef.set(
    {
      approved: false,
      deleted: true,
      deletedAt: FieldValue.serverTimestamp(),
      deleteRequested: false,
    },
    {merge: true},
  );

  const cancelledReservations = await cancelReservationsForStorage(
    storageId,
    "예약하신 창고가 삭제되어 예약이 취소되었습니다.\n" +
      "결제 전이라 청구되는 금액은 없습니다. 다른 창고를 찾아주세요.",
  );

  // 지난 기록이 참조하면 문서를 남긴다. (지우면 상대방 내역이 깨진다)
  const [endeds, reservations] = await Promise.all([
    db.collection("endeds")
      .where("storageId", "==", storageId)
      .limit(1)
      .get(),
    db.collection("reservations")
      .where("storageId", "==", storageId)
      .limit(1)
      .get(),
  ]);
  const hasHistory = !endeds.empty || !reservations.empty;

  let hardDeleted = false;
  if (!hasHistory) {
    const zones = await storageRef.collection("zones").get();
    const batch = db.batch();
    zones.docs.forEach((doc) => batch.delete(doc.ref));
    batch.delete(storageRef);
    await batch.commit();

    // 사진은 등록·수정 모두 storages/{storageId}/ 아래에 올린다.
    try {
      await getStorage()
        .bucket()
        .deleteFiles({prefix: `storages/${storageId}/`});
    } catch (error) {
      logger.warn(`창고 이미지 정리 실패: ${storageId}`, error);
    }
    hardDeleted = true;
  }

  const ownerId = snapshot.data()?.ownerId as string | undefined;
  if (ownerId) {
    const lines = [
      "요청하신 창고 삭제가 승인되었습니다.",
      `창고: ${snapshot.data()?.address ?? storageId}`,
    ];
    if (cancelledReservations > 0) {
      lines.push(
        `시작 전 예약 ${cancelledReservations}건이 함께 취소되었습니다.`,
      );
    }
    await sendSystemMessage(ownerId, lines.join("\n"));
  }

  await writeAdminLog(managerUid, "approveStorageDeletion", storageId, {
    cancelledReservations,
    hardDeleted,
  });
  return {ok: true, hardDeleted, cancelledReservations};
});

/** 삭제 요청을 반려한다. 사유는 주인에게 그대로 전달된다. */
export const rejectStorageDeletion = onCall(async (request) => {
  const managerUid = await requireManager(request.auth?.uid);
  const storageId = String(request.data?.storageId ?? "");
  const reason = String(request.data?.reason ?? "").trim();

  if (!storageId) {
    throw new HttpsError("invalid-argument", "창고를 찾을 수 없습니다.");
  }
  if (!reason) {
    throw new HttpsError("invalid-argument", "반려 사유를 적어주세요.");
  }

  const storageRef = db.collection("storages").doc(storageId);
  const snapshot = await storageRef.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "창고를 찾을 수 없습니다.");
  }

  await storageRef.set({deleteRequested: false}, {merge: true});

  const ownerId = snapshot.data()?.ownerId as string | undefined;
  if (ownerId) {
    await sendSystemMessage(
      ownerId,
      "창고 삭제 요청이 반려되었습니다.\n" +
        `사유: ${reason}\n` +
        `창고: ${snapshot.data()?.address ?? storageId}`,
    );
  }

  await writeAdminLog(managerUid, "rejectStorageDeletion", storageId, {
    reason,
  });
  return {ok: true};
});

/**
 * ─────────────────────────────────────────────────────────────
 * 장소 검색 프록시 (Places API)
 * ─────────────────────────────────────────────────────────────
 *
 * Places 웹 서비스는 앱 신원(SHA)을 실어 보내지 못해서, 앱에 키를 넣으면
 * 제한 없는 키를 공개하는 꼴이 된다. 그래서 서버가 대신 호출한다.
 *  - 키는 Secret Manager(PLACES_API_KEY)에만 있다. 앱에는 키가 없다.
 *  - 로그인한 사용자만 부를 수 있다.
 *  - 검색어 2글자 미만은 호출하지 않는다. (요금 절약)
 */
export const searchPlaces = onCall(
  {secrets: [placesApiKey]},
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const input = String(request.data?.input ?? "").trim();
    if (input.length < 2) return {predictions: []};
    if (input.length > 100) {
      throw new HttpsError("invalid-argument", "검색어가 너무 깁니다.");
    }

    const url = new URL(
      "https://maps.googleapis.com/maps/api/place/autocomplete/json",
    );
    url.searchParams.set("input", input);
    url.searchParams.set("language", "ko");
    url.searchParams.set("components", "country:kr");
    url.searchParams.set("key", placesApiKey.value());

    const response = await fetch(url);
    const data = (await response.json()) as {
      status?: string;
      error_message?: string;
      predictions?: {description?: string; place_id?: string}[];
    };

    if (data.status !== "OK" && data.status !== "ZERO_RESULTS") {
      logger.error("places autocomplete", data.status, data.error_message);
      throw new HttpsError(
        "internal",
        "검색하지 못했어요. 잠시 후 다시 시도해주세요.",
      );
    }

    return {
      predictions: (data.predictions ?? [])
        .filter((item) => item.place_id && item.description)
        .map((item) => ({
          placeId: item.place_id,
          description: item.description,
        })),
    };
  },
);

/** 고른 장소의 좌표를 돌려준다. (지도 이동용) */
export const getPlaceDetail = onCall(
  {secrets: [placesApiKey]},
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const placeId = String(request.data?.placeId ?? "").trim();
    if (!placeId || placeId.length > 200) {
      throw new HttpsError("invalid-argument", "장소를 찾을 수 없습니다.");
    }

    const url = new URL(
      "https://maps.googleapis.com/maps/api/place/details/json",
    );
    url.searchParams.set("place_id", placeId);
    // 좌표만 받는다. (필드를 좁힐수록 요금이 싸다)
    url.searchParams.set("fields", "geometry/location");
    url.searchParams.set("language", "ko");
    url.searchParams.set("key", placesApiKey.value());

    const response = await fetch(url);
    const data = (await response.json()) as {
      status?: string;
      error_message?: string;
      result?: {geometry?: {location?: {lat?: number; lng?: number}}};
    };

    if (data.status !== "OK") {
      logger.error("places detail", data.status, data.error_message);
      throw new HttpsError("internal", "장소 정보를 가져오지 못했어요.");
    }

    const location = data.result?.geometry?.location;
    if (
      typeof location?.lat !== "number" ||
      typeof location?.lng !== "number"
    ) {
      throw new HttpsError("not-found", "장소 좌표가 없습니다.");
    }

    return {lat: location.lat, lng: location.lng};
  },
);
