// firebase_firestore_sync_adapter.dart
// Firebase Firestore sync adapter — PLACEHOLDER (no SDK connected yet).
//
// Data model: /users/{userId}/{collection}/{docId}
//
// To activate:
//   1. Add to pubspec.yaml:
//        cloud_firestore: ^5.x.x
//   2. Uncomment all TODO blocks below
//   3. Set up Firestore security rules:
//      match /users/{userId}/{collection}/{docId} {
//        allow read, write: if request.auth.uid == userId;
//      }

// ignore_for_file: unused_import
// import 'package:cloud_firestore/cloud_firestore.dart';

import 'backend_adapters.dart';

class FirebaseFirestoreSyncAdapter implements SyncAdapter {
  // TODO: FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Future<AdapterResult<void>> push({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    // TODO:
    // await _db
    //     .collection('users')
    //     .doc(userId)
    //     .collection(collection)
    //     .doc(id)
    //     .set({...data, 'updatedAt': FieldValue.serverTimestamp()},
    //          SetOptions(merge: true));
    // return const AdapterResult.success(null);
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<Map<String, dynamic>>> pull({
    required String collection,
    required String id,
  }) async {
    // TODO:
    // final doc = await _db
    //     .collection('users')
    //     .doc(userId)
    //     .collection(collection)
    //     .doc(id)
    //     .get();
    // if (!doc.exists) return AdapterResult.failure('Döküman bulunamadı');
    // return AdapterResult.success(doc.data()!);
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<List<Map<String, dynamic>>>> pullAll({
    required String collection,
    required String userId,
  }) async {
    // TODO:
    // final snapshot = await _db
    //     .collection('users')
    //     .doc(userId)
    //     .collection(collection)
    //     .get();
    // final list = snapshot.docs.map((d) => d.data()).toList();
    // return AdapterResult.success(list);
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<void>> delete({
    required String collection,
    required String id,
  }) async {
    // TODO:
    // await _db
    //     .collection('users')
    //     .doc(userId)
    //     .collection(collection)
    //     .doc(id)
    //     .delete();
    // return const AdapterResult.success(null);
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<int>> syncAll(String userId) async {
    // TODO: iterate collections list, call pullAll for each, merge with local,
    // push updated records, return total synced count.
    return const AdapterResult.failure('Firebase SDK henüz bağlı değil');
  }
}
