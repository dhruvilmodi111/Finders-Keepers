import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/item_repository.dart';
import '../../domain/models/item_model.dart';

final itemRepositoryProvider = Provider<IItemRepository>((ref) {
  return FirestoreItemRepository();
});

class ItemFilterState {
  final ItemType? type;
  final String category;
  final String searchQuery;

  const ItemFilterState({
    this.type,
    this.category = 'All',
    this.searchQuery = '',
  });

  ItemFilterState copyWith({
    ItemType? type,
    String? category,
    String? searchQuery,
  }) {
    return ItemFilterState(
      type: type ?? this.type,
      category: category ?? this.category,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final itemFilterProvider = StateProvider<ItemFilterState>((ref) {
  return const ItemFilterState(type: ItemType.lost);
});

final itemsStreamProvider =
    StreamProvider.autoDispose.family<List<ItemModel>, ItemFilterState>(
  (ref, filter) {
    final repository = ref.watch(itemRepositoryProvider);
    return repository.streamItems(
      type: filter.type,
      category: filter.category,
      searchQuery: filter.searchQuery,
    );
  },
);

final activeFilteredItemsProvider =
    StreamProvider.autoDispose<List<ItemModel>>((ref) {
  final filter = ref.watch(itemFilterProvider);
  final repository = ref.watch(itemRepositoryProvider);
  return repository.streamItems(
    type: filter.type,
    category: filter.category,
    searchQuery: filter.searchQuery,
  );
});

final userItemsStreamProvider =
    StreamProvider.autoDispose.family<List<ItemModel>, String>((ref, userId) {
  final repository = ref.watch(itemRepositoryProvider);
  return repository.streamUserItems(userId);
});

final itemDetailProvider =
    FutureProvider.autoDispose.family<ItemModel?, String>((ref, itemId) {
  final repository = ref.watch(itemRepositoryProvider);
  return repository.getItemById(itemId);
});

class ItemController extends StateNotifier<AsyncValue<void>> {
  final IItemRepository _repository;

  ItemController(this._repository) : super(const AsyncValue.data(null));

  Future<String?> createItem(ItemModel item, {String? hiddenDetail}) async {
    state = const AsyncValue.loading();
    try {
      final id = await _repository.createItem(item, hiddenDetail: hiddenDetail);
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updateStatus(String itemId, ItemStatus status) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateItemStatus(itemId, status);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteItem(String itemId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteItem(itemId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final itemControllerProvider =
    StateNotifierProvider<ItemController, AsyncValue<void>>((ref) {
  final repository = ref.watch(itemRepositoryProvider);
  return ItemController(repository);
});
