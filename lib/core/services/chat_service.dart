import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/conversation_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';

class ChatService {
  final FirebaseFirestore _firestore;

  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String convoId) =>
      _firestore
          .collection('conversations')
          .doc(convoId)
          .collection('messages');

  Stream<List<ConversationModel>> getConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('members', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConversationModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 30,
  }) {
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<List<MessageModel>> loadMoreMessages(
    String conversationId, {
    required DocumentSnapshot lastDocument,
    int limit = 30,
  }) async {
    final snapshot = await _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<DocumentSnapshot?> getMessageDocument(
      String conversationId, String messageId) async {
    final doc = await _messagesRef(conversationId).doc(messageId).get();
    return doc.exists ? doc : null;
  }

  /// Returns the new message document id (for server-verified notify).
  Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final now = DateTime.now();
    final convoRef = _firestore.collection('conversations').doc(conversationId);

    return _firestore.runTransaction<String>((transaction) async {
      final convoSnap = await transaction.get(convoRef);
      if (!convoSnap.exists) {
        throw StateError('Conversation not found');
      }
      final members = List<String>.from(convoSnap.data()?['members'] ?? []);
      final others = members.where((m) => m != senderId).toList();
      if (others.isEmpty) {
        throw StateError('Recipient not found');
      }
      final recipientId = others.first;

      final msgRef = _messagesRef(conversationId).doc();
      transaction.set(msgRef, {
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'clientTimestamp': Timestamp.fromDate(now),
        'status': MessageStatus.sent.name,
      });

      transaction.update(convoRef, {
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.$recipientId': FieldValue.increment(1),
      });

      return msgRef.id;
    });
  }

  Future<String> getOrCreateConversation(
      String currentUserId, String otherUserId) async {
    final query = await _firestore
        .collection('conversations')
        .where('members', arrayContains: currentUserId)
        .get();

    for (final doc in query.docs) {
      final members = List<String>.from(doc.data()['members'] ?? []);
      if (members.contains(otherUserId) && members.length == 2) {
        return doc.id;
      }
    }

    final members = [currentUserId, otherUserId];
    final membersMap = {currentUserId: true, otherUserId: true};

    final newConvo = await _firestore.collection('conversations').add({
      'members': members,
      'membersMap': membersMap,
      'lastMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts': {
        currentUserId: 0,
        otherUserId: 0,
      },
    });

    return newConvo.id;
  }

  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Stream<UserModel?> userStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!) : null);
  }

  Stream<List<UserModel>> searchUsers(String currentUserId) {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  Future<void> markMessagesAsDelivered(
      String conversationId, String currentUserId) async {
    final snapshot = await _messagesRef(conversationId)
        .where('status', isEqualTo: 'sent')
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      if (doc.data()['senderId'] != currentUserId) {
        batch.update(doc.reference, {'status': 'delivered'});
      }
    }
    await batch.commit();
  }

  Future<void> markMessagesAsRead(
      String conversationId, String currentUserId) async {
    final sent = await _messagesRef(conversationId)
        .where('status', isEqualTo: 'sent')
        .get();
    final delivered = await _messagesRef(conversationId)
        .where('status', isEqualTo: 'delivered')
        .get();

    final batch = _firestore.batch();
    final convoRef = _firestore.collection('conversations').doc(conversationId);

    for (final doc in [...sent.docs, ...delivered.docs]) {
      if (doc.data()['senderId'] != currentUserId) {
        batch.update(doc.reference, {'status': 'read'});
      }
    }
    batch.update(convoRef, {'unreadCounts.$currentUserId': 0});
    await batch.commit();
  }
}
