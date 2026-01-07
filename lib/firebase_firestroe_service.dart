import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 保存模型推理结果
  Future<String> savePrediction({
    required String imageUrl,
    required List<Map<String, dynamic>> predictions,
    required String userId,
  }) async {
    try {
      final docRef = await _firestore.collection('predictions').add({
        'imageUrl': imageUrl,
        'predictions': predictions,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      print('Prediction saved with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error saving prediction: $e');
      rethrow;
    }
  }

  // 获取单个预测结果
  Future<Map<String, dynamic>?> getPrediction(String docId) async {
    try {
      final doc = await _firestore.collection('predictions').doc(docId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting prediction: $e');
      rethrow;
    }
  }

  // 获取用户的所有预测结果
  Future<List<Map<String, dynamic>>> getUserPredictions(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('predictions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting user predictions: $e');
      rethrow;
    }
  }

  // 实时监听用户的预测结果
  Stream<List<Map<String, dynamic>>> watchUserPredictions(String userId) {
    return _firestore
        .collection('predictions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
  }

  // 更新预测结果
  Future<void> updatePrediction(
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection('predictions').doc(docId).update(data);
      print('Prediction updated');
    } catch (e) {
      print('Error updating prediction: $e');
      rethrow;
    }
  }

  // 删除预测结果
  Future<void> deletePrediction(String docId) async {
    try {
      await _firestore.collection('predictions').doc(docId).delete();
      print('Prediction deleted');
    } catch (e) {
      print('Error deleting prediction: $e');
      rethrow;
    }
  }

  // 批量操作示例
  Future<void> batchSavePredictions(
    List<Map<String, dynamic>> predictionsData,
    String userId,
  ) async {
    try {
      final batch = _firestore.batch();
      
      for (var prediction in predictionsData) {
        final docRef = _firestore.collection('predictions').doc();
        batch.set(docRef, {
          ...prediction,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      print('Batch predictions saved');
    } catch (e) {
      print('Error batch saving predictions: $e');
      rethrow;
    }
  }
}