import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../items/domain/models/item_model.dart';
import '../../domain/models/claim_model.dart';

abstract class IClaimRepository {
  Future<String> submitClaim(ClaimModel claim);
  Stream<List<ClaimModel>> streamClaimsForItem(String itemId);
  Stream<List<ClaimModel>> streamClaimsForFinder(String finderUserId);
  Stream<List<ClaimModel>> streamClaimsByClaimer(String claimerId);
  Future<String> approveClaim({
    required String claimId,
    required String itemId,
  });
  Future<void> rejectClaim({
    required String claimId,
  });
  Future<bool> completeHandoverWithToken({
    required String claimId,
    required String itemId,
    required String scannedToken,
  });
}

class FirestoreClaimRepository implements IClaimRepository {
  final FirebaseFirestore _firestore;

  FirestoreClaimRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _claimsCollection =>
      _firestore.collection(AppConstants.claimsCollection);

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection(AppConstants.itemsCollection);

  @override
  Future<String> submitClaim(ClaimModel claim) async {
    final docRef = claim.id.isNotEmpty
        ? _claimsCollection.doc(claim.id)
        : _claimsCollection.doc();

    final claimWithId = claim.copyWith(id: docRef.id);
    await docRef.set(claimWithId.toFirestore());
    return docRef.id;
  }

  @override
  Stream<List<ClaimModel>> streamClaimsForItem(String itemId) {
    return _claimsCollection
        .where('itemId', isEqualTo: itemId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ClaimModel.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<ClaimModel>> streamClaimsForFinder(String finderUserId) {
    return _claimsCollection
        .where('itemOwnerId', isEqualTo: finderUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ClaimModel.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<ClaimModel>> streamClaimsByClaimer(String claimerId) {
    return _claimsCollection
        .where('claimerId', isEqualTo: claimerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ClaimModel.fromFirestore(doc)).toList());
  }

  @override
  Future<String> approveClaim({
    required String claimId,
    required String itemId,
  }) async {
    final batch = _firestore.batch();
    final handoverToken = const Uuid().v4();

    // 1. Update Claim document to approved with one-time QR handover token
    final claimRef = _claimsCollection.doc(claimId);
    batch.update(claimRef, {
      'status': ClaimStatus.approved.name,
      'handoverToken': handoverToken,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update Item status to 'claimed'
    final itemRef = _itemsCollection.doc(itemId);
    batch.update(itemRef, {
      'status': ItemStatus.claimed.name,
    });

    await batch.commit();
    return handoverToken;
  }

  @override
  Future<void> rejectClaim({required String claimId}) async {
    await _claimsCollection.doc(claimId).update({
      'status': ClaimStatus.rejected.name,
    });
  }

  @override
  Future<bool> completeHandoverWithToken({
    required String claimId,
    required String itemId,
    required String scannedToken,
  }) async {
    final claimDoc = await _claimsCollection.doc(claimId).get();
    if (!claimDoc.exists) {
      throw Exception('Claim record not found.');
    }

    final claim = ClaimModel.fromFirestore(claimDoc);
    if (claim.handoverToken == null || claim.handoverToken!.trim() != scannedToken.trim()) {
      throw Exception('Invalid or expired handover QR code. Verification failed.');
    }

    // Atomically transition item and claim status to returned
    final batch = _firestore.batch();

    batch.update(_claimsCollection.doc(claimId), {
      'status': ClaimStatus.returned.name,
      'returnedAt': FieldValue.serverTimestamp(),
      'handoverToken': FieldValue.delete(), // Invalidate token upon use
    });

    batch.update(_itemsCollection.doc(itemId), {
      'status': ItemStatus.returned.name,
    });

    await batch.commit();
    return true;
  }
}
