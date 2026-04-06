import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      // Save to Firestore → shows up in Firebase console under "users" collection
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email.trim(),
        'username': username.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await user.updateDisplayName(username.trim());
    }
    return user;
  }

  Future<User?> login({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  Future<User?> signInWithGoogle() async {
    final gUser = await GoogleSignIn().signIn();
    if (gUser == null) return null; // user cancelled

    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;

    // First-time Google user → save profile to Firestore
    if (user != null && userCred.additionalUserInfo?.isNewUser == true) {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'username': user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return user;
  }

  Future<void> savePreferences({
    required String uid,
    String? gender,
    required int age,
    required Map<String, int> appliances,
    required List<String> allergies,
  }) async {
    await _db.collection('users').doc(uid).set({
      'gender': gender,
      'age': age,
      'appliances': appliances,
      'allergies': allergies,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> loadPreferences(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
