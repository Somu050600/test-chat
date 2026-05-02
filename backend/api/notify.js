const { initializeApp, cert, getApps } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

function ensureFirebaseApp() {
  if (getApps().length === 0) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    initializeApp({ credential: cert(serviceAccount) });
  }
}

function setCorsHeaders(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization"
  );
  res.setHeader("Access-Control-Max-Age", "86400");
}

function isConversationMember(convoData, uid) {
  const map = convoData.membersMap;
  if (map && map[uid] === true) return true;
  const members = convoData.members || [];
  return members.includes(uid);
}

module.exports = async function handler(req, res) {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  ensureFirebaseApp();

  const authz = req.headers.authorization || "";
  const match = authz.match(/^Bearer (.+)$/i);
  if (!match) {
    return res.status(401).json({ error: "Missing or invalid Authorization" });
  }

  let uid;
  try {
    const decoded = await getAuth().verifyIdToken(match[1]);
    uid = decoded.uid;
  } catch {
    return res.status(401).json({ error: "Invalid ID token" });
  }

  const { conversationId, messageId } = req.body || {};
  if (!conversationId || !messageId) {
    return res.status(400).json({ error: "Missing conversationId or messageId" });
  }

  try {
    const db = getFirestore();

    const convoDoc = await db
      .collection("conversations")
      .doc(conversationId)
      .get();

    if (!convoDoc.exists) {
      return res.status(404).json({ error: "Conversation not found" });
    }

    const convoData = convoDoc.data();
    if (!isConversationMember(convoData, uid)) {
      return res.status(403).json({ error: "Not a conversation member" });
    }

    const messageDoc = await db
      .collection("conversations")
      .doc(conversationId)
      .collection("messages")
      .doc(messageId)
      .get();

    if (!messageDoc.exists) {
      return res.status(404).json({ error: "Message not found" });
    }

    const messageData = messageDoc.data();
    const senderId = messageData.senderId;
    const text = messageData.text;

    if (senderId !== uid) {
      return res.status(403).json({ error: "Not the message sender" });
    }

    if (typeof text !== "string" || !text) {
      return res.status(400).json({ error: "Invalid message" });
    }

    const members = convoData.members || [];
    const recipientId = members.find((m) => m !== senderId);
    if (!recipientId) {
      return res.status(200).json({ message: "No recipient found" });
    }

    const recipientDoc = await db.collection("users").doc(recipientId).get();
    if (
      recipientDoc.exists &&
      recipientDoc.data().activeConversationId === conversationId
    ) {
      return res.status(200).json({ message: "Recipient is in chat, skipped" });
    }

    const tokensSnapshot = await db
      .collection("users")
      .doc(recipientId)
      .collection("tokens")
      .get();

    if (tokensSnapshot.empty) {
      return res.status(200).json({ message: "No tokens found" });
    }

    const senderUserDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderUserDoc.exists
      ? senderUserDoc.data().name
      : "Someone";

    const tokens = tokensSnapshot.docs.map((doc) => doc.data().token);
    const messaging = getMessaging();

    const payload = {
      notification: {
        title: senderName,
        body: text.length > 100 ? text.substring(0, 100) + "..." : text,
      },
      data: {
        conversationId,
        messageId,
        senderId,
        type: "chat",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    const results = await Promise.allSettled(
      tokens.map((token) => messaging.send({ ...payload, token }))
    );

    const invalidIndices = results
      .map((r, i) => (r.status === "rejected" ? i : -1))
      .filter((i) => i !== -1);

    for (const i of invalidIndices) {
      const reason = results[i].reason;
      if (
        reason?.code === "messaging/invalid-registration-token" ||
        reason?.code === "messaging/registration-token-not-registered"
      ) {
        const tokenDoc = tokensSnapshot.docs[i];
        if (tokenDoc) await tokenDoc.ref.delete();
      }
    }

    const sent = results.filter((r) => r.status === "fulfilled").length;
    return res.status(200).json({ message: `Sent to ${sent} device(s)` });
  } catch (error) {
    console.error("Notification error:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
};
