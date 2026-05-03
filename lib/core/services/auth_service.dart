import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_model.dart';
import '../constants/env.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  GoogleSignIn? _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    late UserCredential userCredential;

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      userCredential = await _auth.signInWithPopup(provider);
    } else {
      if (_googleSignIn == null) {
        _googleSignIn = GoogleSignIn.instance;
        await _googleSignIn!.initialize(
          clientId: Env.googleSignInClientId,
        );
      }
      final account = await _googleSignIn!.authenticate();
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      userCredential = await _auth.signInWithCredential(credential);
    }

    await _saveUserToFirestore(userCredential.user!);
    return userCredential;
  }

  Future<void> _saveUserToFirestore(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      final userModel = UserModel(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL ?? '',
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );
      await docRef.set(userModel.toMap());
    } else {
      await docRef.update({'lastSeen': Timestamp.now()});
    }
  }

  Future<void> setOnlineStatus(bool online) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final update = <String, dynamic>{
      'isOnline': online,
    };
    if (!online) {
      update['lastSeen'] = FieldValue.serverTimestamp();
    }
    try {
      await _firestore.collection('users').doc(user.uid).update(update);
    } catch (e) {
      // Silently fail — user doc may not exist yet
    }
  }

  Future<void> updateLastSeen() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': false,
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> signOut() async {
    await updateLastSeen();
    if (!kIsWeb) await _googleSignIn?.signOut();
    await _auth.signOut();
  }

  Future<void> updateProfile({
    required String name,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name);
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await user.updatePhotoURL(photoUrl);
    }
    await _firestore.collection('users').doc(user.uid).update({
      'name': name,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
  }
}
