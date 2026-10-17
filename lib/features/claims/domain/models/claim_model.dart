import 'package:cloud_firestore/cloud_firestore.dart';

enum ClaimStatus {
  pending,
  approved,
  rejected,
  returned;

  static ClaimStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'approved':
        return ClaimStatus.approved;
      case 'rejected':
        return ClaimStatus.rejected;
      case 'returned':
        return ClaimStatus.returned;
      case 'pending':
      default:
        return ClaimStatus.pending;
    }
  }
}

class ClaimModel {
  final String id;
  final String itemId;
  final String itemTitle;
  final String itemOwnerId;
  final String claimerId;
  final String claimerAlias;
  final Map<String, dynamic> answers;
  final ClaimStatus status;
  final String? handoverToken;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? returnedAt;

  const ClaimModel({
    required this.id,
    required this.itemId,
    this.itemTitle = 'Item',
    required this.itemOwnerId,
    required this.claimerId,
    required this.claimerAlias,
    required this.answers,
    required this.status,
    this.handoverToken,
    required this.createdAt,
    this.approvedAt,
    this.returnedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'itemTitle': itemTitle,
      'itemOwnerId': itemOwnerId,
      'claimerId': claimerId,
      'claimerAlias': claimerAlias,
      'answers': answers,
      'status': status.name,
      if (handoverToken != null) 'handoverToken': handoverToken,
      'createdAt': Timestamp.fromDate(createdAt),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (returnedAt != null) 'returnedAt': Timestamp.fromDate(returnedAt!),
    };
  }

  factory ClaimModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClaimModel.fromMap(data, id: doc.id);
  }

  factory ClaimModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime parsedCreated;
    final createdRaw = map['createdAt'];
    if (createdRaw is Timestamp) {
      parsedCreated = createdRaw.toDate();
    } else if (createdRaw is String) {
      parsedCreated = DateTime.tryParse(createdRaw) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    DateTime? parsedApproved;
    final approvedRaw = map['approvedAt'];
    if (approvedRaw is Timestamp) {
      parsedApproved = approvedRaw.toDate();
    } else if (approvedRaw is String) {
      parsedApproved = DateTime.tryParse(approvedRaw);
    }

    DateTime? parsedReturned;
    final returnedRaw = map['returnedAt'];
    if (returnedRaw is Timestamp) {
      parsedReturned = returnedRaw.toDate();
    } else if (returnedRaw is String) {
      parsedReturned = DateTime.tryParse(returnedRaw);
    }

    // Default alias protects personal email/phone from external exposure
    final alias = map['claimerAlias'] as String? ??
        (map['claimerId'] != null && (map['claimerId'] as String).length >= 4
            ? 'VIT Student #${(map['claimerId'] as String).substring(0, 4).toUpperCase()}'
            : 'VIT Student');

    return ClaimModel(
      id: id,
      itemId: map['itemId'] as String? ?? '',
      itemTitle: map['itemTitle'] as String? ?? 'Item',
      itemOwnerId: map['itemOwnerId'] as String? ?? '',
      claimerId: map['claimerId'] as String? ?? '',
      claimerAlias: alias,
      answers: Map<String, dynamic>.from(map['answers'] as Map? ?? {}),
      status: ClaimStatus.fromString(map['status'] as String? ?? 'pending'),
      handoverToken: map['handoverToken'] as String?,
      createdAt: parsedCreated,
      approvedAt: parsedApproved,
      returnedAt: parsedReturned,
    );
  }

  ClaimModel copyWith({
    String? id,
    String? itemId,
    String? itemTitle,
    String? itemOwnerId,
    String? claimerId,
    String? claimerAlias,
    Map<String, dynamic>? answers,
    ClaimStatus? status,
    String? handoverToken,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? returnedAt,
  }) {
    return ClaimModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemTitle: itemTitle ?? this.itemTitle,
      itemOwnerId: itemOwnerId ?? this.itemOwnerId,
      claimerId: claimerId ?? this.claimerId,
      claimerAlias: claimerAlias ?? this.claimerAlias,
      answers: answers ?? this.answers,
      status: status ?? this.status,
      handoverToken: handoverToken ?? this.handoverToken,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      returnedAt: returnedAt ?? this.returnedAt,
    );
  }
}
