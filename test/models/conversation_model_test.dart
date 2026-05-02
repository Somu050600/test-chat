import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/models/conversation_model.dart';

void main() {
  group('ConversationModel', () {
    test('fromMap creates correct model with membersMap', () {
      final now = DateTime(2024, 1, 1);
      final map = {
        'members': ['uid1', 'uid2'],
        'membersMap': {'uid1': true, 'uid2': true},
        'lastMessage': 'Hello!',
        'updatedAt': Timestamp.fromDate(now),
      };

      final convo = ConversationModel.fromMap('convo-id', map);

      expect(convo.id, 'convo-id');
      expect(convo.members, ['uid1', 'uid2']);
      expect(convo.membersMap, {'uid1': true, 'uid2': true});
      expect(convo.lastMessage, 'Hello!');
      expect(convo.updatedAt, now);
    });

    test('fromMap generates membersMap from members array if missing', () {
      final map = {
        'members': ['uid1', 'uid2'],
        'lastMessage': 'Hi',
        'updatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
      };

      final convo = ConversationModel.fromMap('id', map);

      expect(convo.membersMap, {'uid1': true, 'uid2': true});
    });

    test('toMap includes both members and membersMap', () {
      final convo = ConversationModel(
        id: 'id',
        members: ['uid1', 'uid2'],
        membersMap: {'uid1': true, 'uid2': true},
        lastMessage: 'Hi',
        updatedAt: DateTime(2024, 1, 1),
        unreadCounts: {'uid1': 0, 'uid2': 3},
      );

      final map = convo.toMap();

      expect(map['members'], ['uid1', 'uid2']);
      expect(map['membersMap'], {'uid1': true, 'uid2': true});
      expect(map['lastMessage'], 'Hi');
      expect(map['unreadCounts'], {'uid1': 0, 'uid2': 3});
    });

    test('unreadFor returns count for uid', () {
      final convo = ConversationModel(
        id: 'id',
        members: ['uid1', 'uid2'],
        membersMap: {'uid1': true, 'uid2': true},
        lastMessage: '',
        updatedAt: DateTime.now(),
        unreadCounts: {'uid1': 0, 'uid2': 5},
      );
      expect(convo.unreadFor('uid2'), 5);
      expect(convo.unreadFor('uid1'), 0);
      expect(convo.unreadFor('unknown'), 0);
    });

    test('otherMember returns the other uid', () {
      final convo = ConversationModel(
        id: 'id',
        members: ['uid1', 'uid2'],
        membersMap: {'uid1': true, 'uid2': true},
        lastMessage: '',
        updatedAt: DateTime.now(),
      );

      expect(convo.otherMember('uid1'), 'uid2');
      expect(convo.otherMember('uid2'), 'uid1');
    });

    test('fromMap handles missing fields', () {
      final convo = ConversationModel.fromMap('id', {});

      expect(convo.members, isEmpty);
      expect(convo.membersMap, isEmpty);
      expect(convo.lastMessage, '');
    });
  });
}
