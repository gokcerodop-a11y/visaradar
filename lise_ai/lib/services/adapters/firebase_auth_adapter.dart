// firebase_auth_adapter.dart
// Firebase Auth adapter — PLACEHOLDER (no SDK connected yet).
//
// To activate:
//   1. Add to pubspec.yaml:
//        firebase_core: ^3.x.x
//        firebase_auth: ^5.x.x
//   2. Run `flutterfire configure` to generate google-services.json / GoogleService-Info.plist
//   3. Call `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
//      in main() before runApp()
//   4. Uncomment all TODO blocks below

// ignore_for_file: unused_import
// import 'package:firebase_auth/firebase_auth.dart';

import 'backend_adapters.dart';

class FirebaseAuthAdapter implements AuthAdapter {
  // TODO: FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  AdapterUser? get currentUser {
    // TODO: final user = _auth.currentUser;
    // if (user == null) return null;
    // return _mapUser(user);
    return null;
  }

  @override
  bool get isAuthenticated {
    // TODO: return _auth.currentUser != null;
    return false;
  }

  @override
  Future<AdapterResult<AdapterUser>> signInWithEmail(
      String email, String password) async {
    // TODO:
    // final cred = await _auth.signInWithEmailAndPassword(
    //   email: email, password: password);
    // return AdapterResult.success(_mapUser(cred.user!));
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<AdapterUser>> signInWithApple() async {
    // TODO: use sign_in_with_apple package + OAuthProvider('apple.com')
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<AdapterUser>> signInWithGoogle() async {
    // TODO: use google_sign_in package + GoogleAuthProvider
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<void>> signOut() async {
    // TODO: await _auth.signOut();
    // return const AdapterResult.success(null);
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<AdapterUser>> registerWithEmail(
      String email, String password) async {
    // TODO:
    // final cred = await _auth.createUserWithEmailAndPassword(
    //   email: email, password: password);
    // return AdapterResult.success(_mapUser(cred.user!));
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<void>> resetPassword(String email) async {
    // TODO: await _auth.sendPasswordResetEmail(email: email);
    // return const AdapterResult.success(null);
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<AdapterUser>> updateDisplayName(String name) async {
    // TODO:
    // await _auth.currentUser?.updateDisplayName(name);
    // await _auth.currentUser?.reload();
    // return AdapterResult.success(_mapUser(_auth.currentUser!));
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  // TODO: private mapper
  // AdapterUser _mapUser(User user) => AdapterUser(
  //   id: user.uid,
  //   email: user.email,
  //   displayName: user.displayName,
  //   avatarUrl: user.photoURL,
  //   createdAt: user.metadata.creationTime,
  // );
}
