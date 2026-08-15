/**
 * firestore.rules 검증용 테스트.
 *
 *   cd firestore-tests
 *   npm test
 *
 * (firebase emulators:exec 가 에뮬레이터를 띄운 뒤 이 파일을 실행한다.)
 */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  deleteDoc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const ALICE = 'alice';
const BOB = 'bob';
const CAROL = 'carol';
const BOSS = 'boss';   // 매니저

/**
 * 예약 테스트가 쓰는 "정상 영업 중인 창고".
 *
 * 예약 확정(update)은 살아 있는 창고에서만 되기 때문에,
 * 예약 관련 테스트에는 살아 있는 창고가 하나 필요하다.
 * 창고 규칙 테스트와 섞이지 않도록 id를 따로 쓴다.
 */
const OPEN_STORAGE = 'open1';


const testEnv = await initializeTestEnvironment({
  projectId: 'jimiker-rules-test',
  firestore: {
    rules: readFileSync('../firestore.rules', 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

const asAlice = () => testEnv.authenticatedContext(ALICE).firestore();
const asBob = () => testEnv.authenticatedContext(BOB).firestore();
const asCarol = () => testEnv.authenticatedContext(CAROL).firestore();
const asBoss = () => testEnv.authenticatedContext(BOSS).firestore();
const asGuest = () => testEnv.unauthenticatedContext().firestore();

/** 규칙을 끄고 초기 데이터를 심는다. */
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  // 매니저 계정과 영업 중인 창고는 대부분의 테스트에서 쓰이므로 매번 심어둔다.
  await seed(async (db) => {
    await setDoc(doc(db, 'users', BOSS), {
      uid: BOSS,
      nickName: '관리자',
      userType: 'manager',
    });
    await setDoc(doc(db, 'storages', OPEN_STORAGE), {
      ownerId: BOB,
      approved: true,
      reviewStatus: 'approved',
    });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

// ---------------------------------------------------------------- users

test('users: 본인 문서는 user 등급으로 생성할 수 있다', async () => {
  await assertSucceeds(
    setDoc(doc(asAlice(), 'users', ALICE), {
      uid: ALICE,
      nickName: '앨리스',
      userType: 'user',
    }),
  );
});

test('users: 스스로 manager로 가입할 수 없다', async () => {
  await assertFails(
    setDoc(doc(asAlice(), 'users', ALICE), {
      uid: ALICE,
      userType: 'manager',
    }),
  );
});

test('users: 남의 문서는 만들 수 없다', async () => {
  await assertFails(
    setDoc(doc(asAlice(), 'users', BOB), {uid: BOB, userType: 'user'}),
  );
});

test('users: 등급을 manager로 올릴 수 없다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', ALICE), {uid: ALICE, userType: 'user'});
  });

  await assertFails(
    updateDoc(doc(asAlice(), 'users', ALICE), {userType: 'manager'}),
  );
  await assertSucceeds(
    updateDoc(doc(asAlice(), 'users', ALICE), {nickName: '앨리스2'}),
  );
});

test('users: 로그인하면 상대 프로필을 읽을 수 있고, 비로그인은 못 읽는다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', BOB), {uid: BOB, nickName: '밥'});
  });

  await assertSucceeds(getDoc(doc(asAlice(), 'users', BOB)));
  await assertFails(getDoc(doc(asGuest(), 'users', BOB)));
});

// ------------------------------------------------------------- storages

test('storages: 목록은 비로그인도 통째로 읽을 수 있다 (앱이 그렇게 조회한다)', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'storages', 's1'), {ownerId: BOB, approved: true});
    await setDoc(doc(db, 'storages', 's2'), {ownerId: BOB, approved: false});
  });

  await assertSucceeds(getDocs(collection(asGuest(), 'storages')));
});

test('storages: 본인 소유 + 미승인 상태로만 등록할 수 있다', async () => {
  await assertSucceeds(
    setDoc(doc(asAlice(), 'storages', 's1'), {ownerId: ALICE, approved: false}),
  );
  await assertFails(
    setDoc(doc(asAlice(), 'storages', 's2'), {ownerId: ALICE, approved: true}),
  );
  await assertFails(
    setDoc(doc(asAlice(), 'storages', 's3'), {ownerId: BOB, approved: false}),
  );
});

test('storages: 주인만 수정하고, 스스로 승인할 수 없다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'storages', 's1'), {ownerId: ALICE, approved: false});
  });

  await assertSucceeds(
    updateDoc(doc(asAlice(), 'storages', 's1'), {detailAddress: '101호'}),
  );
  await assertFails(
    updateDoc(doc(asAlice(), 'storages', 's1'), {approved: true}),
  );
  await assertFails(
    updateDoc(doc(asBob(), 'storages', 's1'), {detailAddress: '해킹'}),
  );
});

test('storages: 창고와 zones를 한 배치로 등록할 수 있다', async () => {
  // registerStorage가 storages 문서와 zones를 같은 batch로 쓴다.
  const db = asAlice();
  const batch = writeBatch(db);

  batch.set(doc(db, 'storages', 's1'), {ownerId: ALICE, approved: false});
  batch.set(doc(db, 'storages/s1/zones', 'A'), {index: 'A', price: 1000});
  batch.set(doc(db, 'storages/s1/zones', 'B'), {index: 'B', price: 2000});

  await assertSucceeds(batch.commit());
});

test('storages: 남의 창고를 한 배치로 만들어도 막힌다', async () => {
  const db = asAlice();
  const batch = writeBatch(db);

  batch.set(doc(db, 'storages', 's2'), {ownerId: BOB, approved: false});
  batch.set(doc(db, 'storages/s2/zones', 'A'), {index: 'A', price: 1000});

  await assertFails(batch.commit());
});

test('storages/zones: 주인만 쓸 수 있고 읽기는 공개', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'storages', 's1'), {ownerId: ALICE, approved: true});
    await setDoc(doc(db, 'storages/s1/zones', 'A'), {index: 'A', price: 1000});
  });

  await assertSucceeds(getDoc(doc(asGuest(), 'storages/s1/zones', 'A')));
  await assertSucceeds(
    setDoc(doc(asAlice(), 'storages/s1/zones', 'B'), {index: 'B', price: 2000}),
  );
  await assertFails(
    setDoc(doc(asBob(), 'storages/s1/zones', 'C'), {index: 'C', price: 0}),
  );
});

// ------------------------------------------------------------ chat_rooms

test('chat_rooms: 첫 메시지가 방 문서와 같은 배치로 만들어진다', async () => {
  const db = asAlice();
  const batch = writeBatch(db);
  const roomId = `dm_${ALICE}_${BOB}`;

  batch.set(doc(db, 'chat_rooms', roomId), {
    participantUids: [ALICE, BOB],
    lastMessage: '안녕하세요',
  });
  batch.set(doc(db, `chat_rooms/${roomId}/messages`, 'm1'), {
    uid: ALICE,
    message: '안녕하세요',
    read: false,
  });

  await assertSucceeds(batch.commit());
});

test('chat_rooms: sendMessage와 동일한 트랜잭션으로 첫 메시지가 통과한다', async () => {
  // ChatService.sendMessage 흐름 그대로:
  // 방을 읽어보고(없음) → 메시지 생성 → 방을 merge로 생성.
  const db = asAlice();
  const roomId = `dm_${ALICE}_${BOB}`;
  const roomRef = doc(db, 'chat_rooms', roomId);
  const messageRef = doc(db, `chat_rooms/${roomId}/messages`, 'm1');

  await assertSucceeds(
    runTransaction(db, async (tx) => {
      const snapshot = await tx.get(roomRef);
      assert.equal(snapshot.exists(), false);

      tx.set(messageRef, {uid: ALICE, message: '첫 메시지', read: false});
      tx.set(
        roomRef,
        {
          participantUids: [ALICE, BOB],
          lastMessage: '첫 메시지',
        },
        {merge: true},
      );
    }),
  );
});

test('chat_rooms: 아직 없는 방에 들어가도 메시지 구독이 막히지 않는다', async () => {
  // ChatRoomScreen이 방에 들어가자마자 streamMessages를 구독한다.
  const roomId = `dm_${ALICE}_${BOB}`;
  await assertSucceeds(
    getDocs(collection(asAlice(), `chat_rooms/${roomId}/messages`)),
  );
});

test('chat_rooms: 나를 빼고 방을 만들 수 없다', async () => {
  await assertFails(
    setDoc(doc(asAlice(), 'chat_rooms', 'dm_bob_carol'), {
      participantUids: [BOB, CAROL],
      lastMessage: '끼어들기',
    }),
  );
});

test('chat_rooms: 참여자만 방과 메시지를 읽는다', async () => {
  const roomId = `dm_${ALICE}_${BOB}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', roomId), {
      participantUids: [ALICE, BOB],
      lastMessage: '비밀',
    });
    await setDoc(doc(db, `chat_rooms/${roomId}/messages`, 'm1'), {
      uid: ALICE,
      message: '비밀',
    });
  });

  await assertSucceeds(getDoc(doc(asBob(), 'chat_rooms', roomId)));
  await assertSucceeds(
    getDoc(doc(asBob(), `chat_rooms/${roomId}/messages`, 'm1')),
  );
  await assertFails(getDoc(doc(asCarol(), 'chat_rooms', roomId)));
  await assertFails(
    getDoc(doc(asCarol(), `chat_rooms/${roomId}/messages`, 'm1')),
  );
});

test('chat_rooms: 목록 쿼리(arrayContains)는 통과하고, 전체 조회는 막힌다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', 'r1'), {
      participantUids: [ALICE, BOB],
      lastMessage: 'hi',
    });
    await setDoc(doc(db, 'chat_rooms', 'r2'), {
      participantUids: [BOB, CAROL],
      lastMessage: 'hi',
    });
  });

  await assertSucceeds(
    getDocs(
      query(
        collection(asAlice(), 'chat_rooms'),
        where('participantUids', 'array-contains', ALICE),
      ),
    ),
  );
  await assertFails(getDocs(collection(asAlice(), 'chat_rooms')));
});

test('chat_rooms: 남의 이름으로 메시지를 보낼 수 없다', async () => {
  const roomId = `dm_${ALICE}_${BOB}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', roomId), {
      participantUids: [ALICE, BOB],
      lastMessage: 'hi',
    });
  });

  await assertFails(
    setDoc(doc(asAlice(), `chat_rooms/${roomId}/messages`, 'm2'), {
      uid: BOB,
      message: '사칭',
    }),
  );
  await assertSucceeds(
    setDoc(doc(asAlice(), `chat_rooms/${roomId}/messages`, 'm3'), {
      uid: ALICE,
      message: '정상',
    }),
  );
});

test('chat_rooms: 참여자가 아니면 메시지를 못 남긴다', async () => {
  const roomId = `dm_${ALICE}_${BOB}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', roomId), {
      participantUids: [ALICE, BOB],
      lastMessage: 'hi',
    });
  });

  await assertFails(
    setDoc(doc(asCarol(), `chat_rooms/${roomId}/messages`, 'm9'), {
      uid: CAROL,
      message: '난입',
    }),
  );
});

test('chat_rooms: 메시지는 read만 고칠 수 있고 지울 수 없다', async () => {
  const roomId = `dm_${ALICE}_${BOB}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', roomId), {
      participantUids: [ALICE, BOB],
      lastMessage: 'hi',
    });
    await setDoc(doc(db, `chat_rooms/${roomId}/messages`, 'm1'), {
      uid: ALICE,
      message: '원본',
      read: false,
    });
  });

  await assertSucceeds(
    updateDoc(doc(asBob(), `chat_rooms/${roomId}/messages`, 'm1'), {read: true}),
  );
  await assertFails(
    updateDoc(doc(asBob(), `chat_rooms/${roomId}/messages`, 'm1'), {
      message: '조작',
    }),
  );
  await assertFails(
    deleteDoc(doc(asAlice(), `chat_rooms/${roomId}/messages`, 'm1')),
  );
});

test('chat_rooms: 본인 시스템 방에만 system 메시지를 남길 수 있다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', `system_${ALICE}`), {
      participantUids: [ALICE, 'system'],
      lastMessage: 'hi',
    });
    await setDoc(doc(db, 'chat_rooms', `system_${BOB}`), {
      participantUids: [BOB, 'system'],
      lastMessage: 'hi',
    });
  });

  await assertSucceeds(
    setDoc(doc(asAlice(), `chat_rooms/system_${ALICE}/messages`, 'm1'), {
      uid: 'system',
      message: '창고 등록 신청이 완료되었습니다.',
    }),
  );
  // 남의 시스템 방은 참여자도 아니므로 당연히 막힌다.
  await assertFails(
    setDoc(doc(asAlice(), `chat_rooms/system_${BOB}/messages`, 'm2'), {
      uid: 'system',
      message: '사칭',
    }),
  );
});

test('chat_rooms: 나를 참여자에서 빼는 수정은 막는다', async () => {
  const roomId = `dm_${ALICE}_${BOB}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', roomId), {
      participantUids: [ALICE, BOB],
      lastMessage: 'hi',
    });
  });

  await assertFails(
    updateDoc(doc(asAlice(), 'chat_rooms', roomId), {participantUids: [BOB]}),
  );
});

// ---------------------------------------------------------- reservations

test('reservations: 앱에서 직접 만들 수 없다 (서버 전용)', async () => {
  // 기간 겹침은 규칙으로 볼 수 없어서 createReservation 함수가 만든다.
  // 본인 이름에 waiting 상태여도, 살아 있는 창고여도 막혀야 한다.
  await assertFails(
    setDoc(doc(asAlice(), 'reservations', 'r1'), {
      userId: ALICE,
      ownerId: BOB,
      storageId: OPEN_STORAGE,
      status: 'waiting',
    }),
  );
});

test('reservations: 날짜 겹침 확인용 조회(storageId)는 통과한다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'reservations', 'r1'), {
      userId: BOB,
      ownerId: CAROL,
      storageId: OPEN_STORAGE,
      containerIndex: 'A',
      status: 'approved',
    });
  });

  await assertSucceeds(
    getDocs(
      query(
        collection(asAlice(), 'reservations'),
        where('storageId', '==', OPEN_STORAGE),
        where('containerIndex', '==', 'A'),
      ),
    ),
  );
  await assertFails(getDocs(collection(asGuest(), 'reservations')));
});

test('reservations: 창고 주인은 상태를 바꾸고, 제3자는 못 바꾼다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'reservations', 'r1'), {
      userId: ALICE,
      ownerId: BOB,
      storageId: OPEN_STORAGE,
      status: 'waiting',
    });
  });

  await assertSucceeds(
    updateDoc(doc(asBob(), 'reservations', 'r1'), {status: 'approved'}),
  );
  await assertFails(
    updateDoc(doc(asCarol(), 'reservations', 'r1'), {status: 'approved'}),
  );
  // 예약자를 바꿔치기할 수 없다.
  await assertFails(
    updateDoc(doc(asBob(), 'reservations', 'r1'), {userId: CAROL}),
  );
});

test('reservations: 대기중인 예약은 예약자가 취소할 수 있다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'reservations', 'r1'), {
      userId: ALICE,
      ownerId: BOB,
      storageId: OPEN_STORAGE,
      status: 'waiting',
    });
  });

  await assertSucceeds(deleteDoc(doc(asAlice(), 'reservations', 'r1')));
});

test('reservations: 확정된 예약은 예약자가 지울 수 없다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'reservations', 'r1'), {
      userId: ALICE,
      ownerId: BOB,
      storageId: OPEN_STORAGE,
      status: 'approved',
    });
  });

  // 예약자는 막히고, 창고 주인은 정리할 수 있다.
  await assertFails(deleteDoc(doc(asAlice(), 'reservations', 'r1')));
  await assertSucceeds(deleteDoc(doc(asBob(), 'reservations', 'r1')));
});

test('reservations: 주인이 거절로 바꾸면 예약자가 내역을 지울 수 있다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'reservations', 'r1'), {
      userId: ALICE,
      ownerId: BOB,
      storageId: OPEN_STORAGE,
      status: 'approved',
    });
  });

  await assertSucceeds(
    updateDoc(doc(asBob(), 'reservations', 'r1'), {status: 'rejected'}),
  );
  await assertSucceeds(deleteDoc(doc(asAlice(), 'reservations', 'r1')));
});

test('reservations: 제3자는 남의 예약을 지울 수 없다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'reservations', 'r1'), {
      userId: ALICE,
      ownerId: BOB,
      storageId: OPEN_STORAGE,
      status: 'waiting',
    });
  });

  await assertFails(deleteDoc(doc(asCarol(), 'reservations', 'r1')));
});

test('reservations: 반려된 창고의 예약은 확정할 수 없고 정리만 된다', async () => {
  // 관리자가 반려하면서 취소해둔 예약을 주인이 되살리지 못해야 한다.
  await seed(async (db) => {
    await setDoc(doc(db, 'storages', 'closed1'), {
      ownerId: BOB,
      approved: false,
      reviewStatus: 'rejected',
    });
    await setDoc(doc(db, 'reservations', 'r1'), {
      userId: ALICE,
      ownerId: BOB,
      storageId: 'closed1',
      status: 'rejected',
    });
  });

  await assertFails(
    updateDoc(doc(asBob(), 'reservations', 'r1'), {status: 'approved'}),
  );
  // 정리(거절 유지·삭제)는 언제든 가능해야 한다.
  await assertSucceeds(
    updateDoc(doc(asBob(), 'reservations', 'r1'), {status: 'rejected'}),
  );
  await assertSucceeds(deleteDoc(doc(asAlice(), 'reservations', 'r1')));
});

// ------------------------------------------------------------- 관리자

test('users: 매니저만 사용자 목록을 볼 수 있다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', ALICE), {uid: ALICE, userType: 'user'});
  });

  await assertSucceeds(getDocs(collection(asBoss(), 'users')));
  await assertFails(getDocs(collection(asAlice(), 'users')));
});

test('storages: 주인도 심사 필드는 건드릴 수 없다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'storages', 's1'), {
      ownerId: ALICE,
      approved: false,
      reviewStatus: 'pending',
    });
  });

  await assertFails(
    updateDoc(doc(asAlice(), 'storages', 's1'), {reviewStatus: 'approved'}),
  );
  await assertFails(
    updateDoc(doc(asAlice(), 'storages', 's1'), {rejectReason: ''}),
  );
  // 심사와 무관한 수정은 그대로 된다.
  await assertSucceeds(
    updateDoc(doc(asAlice(), 'storages', 's1'), {detailAddress: '101호'}),
  );
});

test('storages: 매니저도 규칙으로는 승인할 수 없다 (Functions 전용)', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'storages', 's1'), {
      ownerId: ALICE,
      approved: false,
      reviewStatus: 'pending',
    });
  });

  await assertFails(
    updateDoc(doc(asBoss(), 'storages', 's1'), {approved: true}),
  );
});

test('정지된 계정은 창고 등록이 막힌다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', ALICE), {
      uid: ALICE,
      userType: 'user',
      suspended: true,
    });
  });

  await assertFails(
    setDoc(doc(asAlice(), 'storages', 's9'), {
      ownerId: ALICE,
      approved: false,
    }),
  );
});

test('정지된 계정도 채팅과 읽기는 된다', async () => {
  const roomId = `dm_${ALICE}_${BOB}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'users', ALICE), {
      uid: ALICE,
      userType: 'user',
      suspended: true,
    });
    await setDoc(doc(db, 'chat_rooms', roomId), {
      participantUids: [ALICE, BOB],
      lastMessage: 'hi',
    });
  });

  // 진행 중인 거래를 정리하려면 대화는 열려 있어야 한다.
  await assertSucceeds(
    setDoc(doc(asAlice(), `chat_rooms/${roomId}/messages`, 'm1'), {
      uid: ALICE,
      message: '정리하겠습니다',
    }),
  );
  await assertSucceeds(getDoc(doc(asAlice(), 'storages', 's1')));
});

test('정지되지 않은 계정은 그대로 창고를 올릴 수 있다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', ALICE), {uid: ALICE, userType: 'user'});
  });

  await assertSucceeds(
    setDoc(doc(asAlice(), 'storages', 's9'), {
      ownerId: ALICE,
      approved: false,
    }),
  );
});

test('admin_logs: 매니저만 읽고 아무도 쓰지 못한다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'admin_logs', 'l1'), {
      actorUid: BOSS,
      action: 'approveStorage',
      targetId: 's1',
    });
  });

  await assertSucceeds(getDocs(collection(asBoss(), 'admin_logs')));
  await assertFails(getDocs(collection(asAlice(), 'admin_logs')));
  await assertFails(
    setDoc(doc(asBoss(), 'admin_logs', 'l2'), {action: '위조'}),
  );
});

// -------------------------------------------------------- usages / endeds

test('usages/endeds: 읽기만 되고 클라이언트 쓰기는 막힌다', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'usages', 'u1'), {userId: ALICE, storageId: 's1'});
    await setDoc(doc(db, 'endeds', 'e1'), {userId: ALICE, storageId: 's1'});
  });

  await assertSucceeds(
    getDocs(
      query(collection(asAlice(), 'usages'), where('userId', '==', ALICE)),
    ),
  );
  await assertSucceeds(
    getDocs(
      query(collection(asAlice(), 'endeds'), where('userId', '==', ALICE)),
    ),
  );
  await assertFails(
    setDoc(doc(asAlice(), 'usages', 'u2'), {userId: ALICE, storageId: 's1'}),
  );
  await assertFails(deleteDoc(doc(asAlice(), 'endeds', 'e1')));
});

// ------------------------------------------------------------------ 기타

test('정의되지 않은 컬렉션은 전부 막힌다', async () => {
  await assertFails(setDoc(doc(asAlice(), 'anything', 'x'), {a: 1}));
  await assertFails(getDoc(doc(asAlice(), 'anything', 'x')));
});

test('locations: 읽기는 공개, 쓰기는 로그인 필요', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'locations', 'l1'), {address: '서울', storages: []});
  });

  await assertSucceeds(getDoc(doc(asGuest(), 'locations', 'l1')));
  await assertSucceeds(
    updateDoc(doc(asAlice(), 'locations', 'l1'), {storages: ['s1']}),
  );
  await assertFails(
    setDoc(doc(asGuest(), 'locations', 'l2'), {address: '부산'}),
  );
  await assertFails(deleteDoc(doc(asAlice(), 'locations', 'l1')));
});

assert.ok(true);

// ------------------------------------------------- 채팅 안 읽은 수

test('chat_rooms: 내 안 읽은 수만 0으로 되돌릴 수 있다', async () => {
  const roomId = `dm_${ALICE}_${BOB}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', roomId), {
      participantUids: [ALICE, BOB],
      lastMessage: 'hi',
      unreadCounts: {[ALICE]: 3, [BOB]: 1},
    });
  });

  await assertSucceeds(
    updateDoc(doc(asAlice(), 'chat_rooms', roomId), {
      [`unreadCounts.${ALICE}`]: 0,
    }),
  );

  // 상대의 안 읽음 표시를 지워버릴 수 없어야 한다.
  await assertFails(
    updateDoc(doc(asAlice(), 'chat_rooms', roomId), {
      [`unreadCounts.${BOB}`]: 0,
    }),
  );
  // 내 것과 남의 것을 한꺼번에 바꾸는 것도 막힌다.
  await assertFails(
    updateDoc(doc(asAlice(), 'chat_rooms', roomId), {
      unreadCounts: {[ALICE]: 0, [BOB]: 0},
    }),
  );
});

test('chat_rooms: 안 읽은 수가 없던 방에도 내 것을 넣을 수 있다', async () => {
  // Functions 배포 전에 만들어진 방에는 unreadCounts 자체가 없다.
  const roomId = `dm_${ALICE}_${BOB}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', roomId), {
      participantUids: [ALICE, BOB],
      lastMessage: 'hi',
    });
  });

  await assertSucceeds(
    updateDoc(doc(asAlice(), 'chat_rooms', roomId), {
      unreadCounts: {[ALICE]: 0},
    }),
  );
});

test('chat_rooms: 제3자는 안 읽은 수를 못 건드린다', async () => {
  const roomId = `dm_${ALICE}_${BOB}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'chat_rooms', roomId), {
      participantUids: [ALICE, BOB],
      lastMessage: 'hi',
      unreadCounts: {[ALICE]: 2},
    });
  });

  await assertFails(
    updateDoc(doc(asCarol(), 'chat_rooms', roomId), {
      [`unreadCounts.${CAROL}`]: 0,
    }),
  );
});
