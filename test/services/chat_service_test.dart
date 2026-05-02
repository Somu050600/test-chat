import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/services/chat_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ChatService chatService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    chatService = ChatService(firestore: fakeFirestore);
  });

  group('ChatService', () {
    test('getOrCreateConversation creates with membersMap', () async {
      final id = await chatService.getOrCreateConversation('uid1', 'uid2');

      expect(id, isNotEmpty);

      final doc =
          await fakeFirestore.collection('conversations').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['members'], ['uid1', 'uid2']);
      expect(doc.data()!['membersMap'], {'uid1': true, 'uid2': true});
      expect(doc.data()!['unreadCounts'], {'uid1': 0, 'uid2': 0});
    });

    test('getOrCreateConversation returns existing conversation', () async {
      final first = await chatService.getOrCreateConversation('uid1', 'uid2');
      final second = await chatService.getOrCreateConversation('uid1', 'uid2');

      expect(first, second);
    });

    test('sendMessage adds document with server timestamp fields', () async {
      final convoId =
          await chatService.getOrCreateConversation('uid1', 'uid2');

      final messageId = await chatService.sendMessage(
        conversationId: convoId,
        senderId: 'uid1',
        text: 'Hello!',
      );

      final messages = await fakeFirestore
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .get();
      expect(messages.docs, hasLength(1));
      expect(messages.docs.first.id, messageId);

      final data = messages.docs.first.data();
      expect(data['text'], 'Hello!');
      expect(data['senderId'], 'uid1');
      expect(data['status'], 'sent');
      expect(data['clientTimestamp'], isNotNull);

      final convo =
          await fakeFirestore.collection('conversations').doc(convoId).get();
      expect(convo.data()!['lastMessage'], 'Hello!');
    });

    test('getUser returns user model', () async {
      await fakeFirestore.collection('users').doc('uid1').set({
        'uid': 'uid1',
        'name': 'Test User',
        'email': 'test@test.com',
        'photoUrl': '',
      });

      final user = await chatService.getUser('uid1');

      expect(user, isNotNull);
      expect(user!.name, 'Test User');
    });

    test('getUser returns null for non-existent user', () async {
      final user = await chatService.getUser('nonexistent');
      expect(user, isNull);
    });

    test('getConversations streams conversations for user', () async {
      await fakeFirestore.collection('conversations').add({
        'members': ['uid1', 'uid2'],
        'membersMap': {'uid1': true, 'uid2': true},
        'lastMessage': 'Hi',
        'updatedAt': DateTime.now(),
      });
      await fakeFirestore.collection('conversations').add({
        'members': ['uid3', 'uid4'],
        'membersMap': {'uid3': true, 'uid4': true},
        'lastMessage': 'Bye',
        'updatedAt': DateTime.now(),
      });

      final convos = await chatService.getConversations('uid1').first;

      expect(convos, hasLength(1));
      expect(convos.first.members, contains('uid1'));
    });

    test('markMessagesAsDelivered updates sent to delivered', () async {
      final convoId =
          await chatService.getOrCreateConversation('uid1', 'uid2');

      await fakeFirestore
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .add({
        'senderId': 'uid1',
        'text': 'Hello',
        'status': 'sent',
      });

      await chatService.markMessagesAsDelivered(convoId, 'uid2');

      final msgs = await fakeFirestore
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .get();
      expect(msgs.docs.first.data()['status'], 'delivered');
    });

    test('markMessagesAsRead updates sent and delivered to read', () async {
      final convoId =
          await chatService.getOrCreateConversation('uid1', 'uid2');
      final ref = fakeFirestore
          .collection('conversations')
          .doc(convoId)
          .collection('messages');

      await ref.add({'senderId': 'uid1', 'text': 'A', 'status': 'sent'});
      await ref.add({'senderId': 'uid1', 'text': 'B', 'status': 'delivered'});

      await chatService.markMessagesAsRead(convoId, 'uid2');

      final msgs = await ref.get();
      for (final doc in msgs.docs) {
        expect(doc.data()['status'], 'read');
      }

      final convoDoc = await fakeFirestore
          .collection('conversations')
          .doc(convoId)
          .get();
      expect(convoDoc.data()!['unreadCounts']['uid2'], 0);
    });
  });
}
