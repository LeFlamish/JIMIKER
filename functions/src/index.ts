/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app"
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

    // ✅ A) "채팅"을 Firestore에 생성(너의 채팅 구조에 맞게 경로만 바꿔)
    // 예: users/{uid}/chats/system/messages/{autoId}
    await db
      .collection("users")
      .doc(ownerId)
      .collection("systemMessages")
      .add({
        type: "storage_approved",
        title: "창고 등록 승인",
        body: `등록하신 창고(${locationId})가 승인되었습니다.`,
        locationId,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });

    // ✅ B) (선택) approved 시 storage 문서에 승인시각 기록 등도 가능
    // await event.data?.after.ref.update({ approvedAt: FieldValue.serverTimestamp() });
  }
);

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
