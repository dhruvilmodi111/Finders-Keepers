import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/item_model.dart';

abstract class IItemRepository {
  Stream<List<ItemModel>> streamItems({
    ItemType? type,
    String? category,
    String? searchQuery,
  });

  Stream<List<ItemModel>> streamUserItems(String userId);

  Future<ItemModel?> getItemById(String itemId);

  Future<String> createItem(ItemModel item, {String? hiddenDetail});

  Future<void> updateItem(ItemModel item);

  Future<void> updateItemStatus(String itemId, ItemStatus status);

  Future<void> deleteItem(String itemId);

  Future<String?> getHiddenDetail({
    required String itemId,
    required String requesterId,
  });
}

class FirestoreItemRepository implements IItemRepository {
  final FirebaseFirestore _firestore;

  FirestoreItemRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection(AppConstants.itemsCollection);

  @override
  Stream<List<ItemModel>> streamItems({
    ItemType? type,
    String? category,
    String? searchQuery,
  }) {
    Query<Map<String, dynamic>> query =
        _itemsCollection.orderBy('createdAt', descending: true);

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    if (category != null && category != 'All' && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      var items = snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final queryLower = searchQuery.trim().toLowerCase();
        items = items.where((item) {
          final titleMatch = item.title.toLowerCase().contains(queryLower);
          final descMatch =
              item.description.toLowerCase().contains(queryLower);
          final locMatch =
              item.location.label.toLowerCase().contains(queryLower);
          final catMatch = item.category.toLowerCase().contains(queryLower);
          return titleMatch || descMatch || locMatch || catMatch;
        }).toList();
      }

      return items;
    });
  }

  @override
  Stream<List<ItemModel>> streamUserItems(String userId) {
    return _itemsCollection
        .where('ownerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList());
  }

  @override
  Future<ItemModel?> getItemById(String itemId) async {
    final doc = await _itemsCollection.doc(itemId).get();
    if (!doc.exists) return null;
    return ItemModel.fromFirestore(doc);
  }

  @override
  Future<String> createItem(ItemModel item, {String? hiddenDetail}) async {
    // Generate doc reference
    final docRef = item.id.isNotEmpty
        ? _itemsCollection.doc(item.id)
        : _itemsCollection.doc();

    final itemWithId = item.copyWith(id: docRef.id);

    // Write public item document
    await docRef.set(itemWithId.toFirestore());

    // Write private verification details to secure subcollection
    if (hiddenDetail != null && hiddenDetail.isNotEmpty) {
      await docRef.collection('private').doc('verification').set({
        'hiddenDetail': hiddenDetail,
        'hiddenDetailHash': item.hiddenDetailHash,
        'ownerId': item.ownerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return docRef.id;
  }

  @override
  Future<void> updateItem(ItemModel item) async {
    await _itemsCollection.doc(item.id).update(item.toFirestore());
  }

  @override
  Future<void> updateItemStatus(String itemId, ItemStatus status) async {
    await _itemsCollection.doc(itemId).update({
      'status': status.name,
    });
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _itemsCollection.doc(itemId).delete();
  }

  @override
  Future<String?> getHiddenDetail({
    required String itemId,
    required String requesterId,
  }) async {
    // Verified by security rules that only the owner can read this subcollection doc
    final secretDoc = await _itemsCollection
        .doc(itemId)
        .collection('private')
        .doc('verification')
        .get();

    if (!secretDoc.exists) return null;
    return secretDoc.data()?['hiddenDetail'] as String?;
  }
}
