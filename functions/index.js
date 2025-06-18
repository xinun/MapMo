const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

exports.updateEmotionStats = onDocumentWritten("users/{userId}/diaries/{diaryId}", async (event) => {
  const userId = event.params.userId;
  const afterData = event.data.after ? event.data.after.data() : null;
  const beforeData = event.data.before ? event.data.before.data() : null;

  const statsRef = db.collection("users").doc(userId).collection("emotionStats").doc("summary");

  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(statsRef);
    const current = snapshot.exists ? snapshot.data().counts || {} : {};

    if (beforeData?.emotion && (!afterData || beforeData.emotion !== afterData.emotion)) {
      current[beforeData.emotion] = (current[beforeData.emotion] || 0) - 1;
      if (current[beforeData.emotion] <= 0) delete current[beforeData.emotion];
    }

    if (afterData?.emotion) {
      current[afterData.emotion] = (current[afterData.emotion] || 0) + 1;
    }

    tx.set(statsRef, {counts: current});
  });

  console.log(`✅ 감정 통계 업데이트됨 for user ${userId}`);
});
