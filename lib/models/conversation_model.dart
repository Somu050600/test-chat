import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> members;
  final Map<String, bool> membersMap;
  final String lastMessage;
  final DateTime updatedAt;
  /// Per-user unread counts (denormalized). Keys are member UIDs.
  final Map<String, int> unreadCounts;

  const ConversationModel({
    required this.id,
    required this.members,
    required this.membersMap,
    required this.lastMessage,
    required this.updatedAt,
    this.unreadCounts = const {},
  });

  int unreadFor(String uid) => unreadCounts[uid] ?? 0;

  factory ConversationModel.fromMap(String id, Map<String, dynamic> map) {
    final members = List<String>.from(map['members'] ?? []);
    final membersMap = Map<String, bool>.from(map['membersMap'] ?? {});
    if (membersMap.isEmpty && members.isNotEmpty) {
      for (final uid in members) {
        membersMap[uid] = true;
      }
    }

    final rawUnread = map['unreadCounts'];
    final Map<String, int> unreadCounts = {};
    if (rawUnread is Map) {
      for (final e in rawUnread.entries) {
        final v = e.value;
        if (v is int) {
          unreadCounts[e.key.toString()] = v;
        } else if (v is num) {
          unreadCounts[e.key.toString()] = v.toInt();
        }
      }
    }

    return ConversationModel(
      id: id,
      members: members,
      membersMap: membersMap,
      lastMessage: map['lastMessage'] as String? ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: unreadCounts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
        'members': members,
        'membersMap': membersMap,
        'lastMessage': lastMessage,
        'updatedAt': Timestamp.fromDate(updatedAt),
        if (unreadCounts.isNotEmpty) 'unreadCounts': unreadCounts,
      };
  }

  String otherMember(String currentUid) {
    return members.firstWhere((m) => m != currentUid, orElse: () => '');
  }
}
