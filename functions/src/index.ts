/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

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
              participantUids: [ownerId, "system"],
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

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
