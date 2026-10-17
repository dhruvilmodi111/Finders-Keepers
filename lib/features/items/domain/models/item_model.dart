import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemType {
  lost,
  found;

  static ItemType fromString(String val) =>
      val.toLowerCase() == 'found' ? ItemType.found : ItemType.lost;
}

enum ItemStatus {
  lost,
  found,
  claimed,
  returned;

  static ItemStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'found':
        return ItemStatus.found;
      case 'claimed':
        return ItemStatus.claimed;
      case 'returned':
        return ItemStatus.returned;
      case 'lost':
      default:
        return ItemStatus.lost;
    }
  }
}

class ItemLocation {
  final double latitude;
  final double longitude;
  final String label;

  const ItemLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
    };
  }

  factory ItemLocation.fromMap(Map<String, dynamic> map) {
    return ItemLocation(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      label: map['label'] as String? ?? 'Campus',
    );
  }
}

class ItemModel {
  final String id;
  final ItemType type;
  final String title;
  final String category;
  final String description;
  final List<String> imageUrls;
  final ItemLocation location;
  final ItemStatus status;
  final String ownerId;
  final String hiddenDetailHash;
  final DateTime createdAt;
  final bool isPendingSync;

  const ItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.description,
    required this.imageUrls,
    required this.location,
    required this.status,
    required this.ownerId,
    required this.hiddenDetailHash,
    required this.createdAt,
    this.isPendingSync = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'title': title,
      'category': category,
      'description': description,
      'imageUrls': imageUrls,
      'location': location.toMap(),
      'status': status.name,
      'ownerId': ownerId,
      'hiddenDetailHash': hiddenDetailHash,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ItemModel.fromMap(data, id: doc.id);
  }

  factory ItemModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime parsedDate;
    final createdRaw = map['createdAt'];
    if (createdRaw is Timestamp) {
      parsedDate = createdRaw.toDate();
    } else if (createdRaw is String) {
      parsedDate = DateTime.tryParse(createdRaw) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ItemModel(
      id: id,
      type: ItemType.fromString(map['type'] as String? ?? 'lost'),
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? 'Others',
      description: map['description'] as String? ?? '',
      imageUrls: List<String>.from(map['imageUrls'] as List? ?? []),
      location: ItemLocation.fromMap(map['location'] as Map<String, dynamic>? ?? {}),
      status: ItemStatus.fromString(map['status'] as String? ?? 'lost'),
      ownerId: map['ownerId'] as String? ?? '',
      hiddenDetailHash: map['hiddenDetailHash'] as String? ?? '',
      createdAt: parsedDate,
      isPendingSync: map['isPendingSync'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'category': category,
      'description': description,
      'imageUrls': imageUrls,
      'location': location.toMap(),
      'status': status.name,
      'ownerId': ownerId,
      'hiddenDetailHash': hiddenDetailHash,
      'createdAt': createdAt.toIso8601String(),
      'isPendingSync': isPendingSync,
    };
  }

  String toJson() => jsonEncode(toJsonMap());

  factory ItemModel.fromJson(String source) =>
      ItemModel.fromMap(jsonDecode(source) as Map<String, dynamic>,
          id: (jsonDecode(source)['id'] as String?) ?? '');

  ItemModel copyWith({
    String? id,
    ItemType? type,
    String? title,
    String? category,
    String? description,
    List<String>? imageUrls,
    ItemLocation? location,
    ItemStatus? status,
    String? ownerId,
    String? hiddenDetailHash,
    DateTime? createdAt,
    bool? isPendingSync,
  }) {
    return ItemModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      location: location ?? this.location,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      hiddenDetailHash: hiddenDetailHash ?? this.hiddenDetailHash,
      createdAt: createdAt ?? this.createdAt,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }
}
