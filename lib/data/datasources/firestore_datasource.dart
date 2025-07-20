import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class FirestoreDataSource {
  final FirebaseFirestore _firestore;

  FirestoreDataSource(this._firestore);

  // Add a new user document
  Future<void> createUser(UserModel user) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.id)
        .set(user.toMap());
  }

  // Retrieve a user document by ID
  Future<UserModel?> getUserById(String id) async {
    final doc =
        await _firestore.collection(AppConstants.usersCollection).doc(id).get();

    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Stream for a user document by ID
  Stream<UserModel?> getUserStream(String id) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(id)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Retrieve all user documents
  Future<List<UserModel>> getAllUsers() async {
    final querySnapshot =
        await _firestore.collection(AppConstants.usersCollection).get();

    return querySnapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Update a user document by ID
  Future<void> updateUser(UserModel user) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.id)
        .update(user.toMap());
  }

  // Delete a user document by ID
  Future<void> deleteUser(String id) async {
    await _firestore.collection(AppConstants.usersCollection).doc(id).delete();
  }

  // Update a specific field in a user document by ID
  Future<void> updateUserField(String id, String field, dynamic value) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(id)
        .update({field: value});
  }

  // Increase or decrease the tokensUsed field in a user document by ID
  Future<void> updateTokensUsed(String id, int delta) async {
    final docRef = _firestore.collection(AppConstants.usersCollection).doc(id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception("User does not exist!");
      }

      final currentTokens = snapshot.data()?['tokensUsed'] ?? 0;
      final newTokensUsed = currentTokens + delta;

      transaction.update(docRef, {'tokensUsed': newTokensUsed});
    });
  }
}
