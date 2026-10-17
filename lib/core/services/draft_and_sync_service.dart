import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../features/items/data/repositories/item_repository.dart';
import '../../features/items/domain/models/item_model.dart';

class ReportDraft {
  final int step;
  final ItemType type;
  final String category;
  final List<String> localImagePaths;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String locationLabel;
  final String hiddenDetail;
  final DateTime updatedAt;

  const ReportDraft({
    this.step = 0,
    this.type = ItemType.lost,
    this.category = 'Electronics',
    this.localImagePaths = const [],
    this.title = '',
    this.description = '',
    this.latitude = 12.9698,
    this.longitude = 79.1559,
    this.locationLabel = 'VIT Campus',
    this.hiddenDetail = '',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'step': step,
      'type': type.name,
      'category': category,
      'localImagePaths': localImagePaths,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'locationLabel': locationLabel,
      'hiddenDetail': hiddenDetail,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReportDraft.fromMap(Map<String, dynamic> map) {
    return ReportDraft(
      step: map['step'] as int? ?? 0,
      type: ItemType.fromString(map['type'] as String? ?? 'lost'),
      category: map['category'] as String? ?? 'Electronics',
      localImagePaths: List<String>.from(map['localImagePaths'] as List? ?? []),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 12.9698,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 79.1559,
      locationLabel: map['locationLabel'] as String? ?? 'VIT Campus',
      hiddenDetail: map['hiddenDetail'] as String? ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class QueuedItemReport {
  final String id;
  final ItemModel item;
  final List<String> localImagePaths;
  final String? hiddenDetail;
  final DateTime createdAt;

  const QueuedItemReport({
    required this.id,
    required this.item,
    required this.localImagePaths,
    this.hiddenDetail,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item': item.toJsonMap(),
      'localImagePaths': localImagePaths,
      'hiddenDetail': hiddenDetail,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory QueuedItemReport.fromMap(Map<String, dynamic> map) {
    return QueuedItemReport(
      id: map['id'] as String? ?? const Uuid().v4(),
      item: ItemModel.fromMap(
        map['item'] as Map<String, dynamic>? ?? {},
        id: (map['item']?['id'] as String?) ?? '',
      ),
      localImagePaths: List<String>.from(map['localImagePaths'] as List? ?? []),
      hiddenDetail: map['hiddenDetail'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class DraftAndSyncService {
  static const String _draftKey = 'report_item_draft_v1';
  static const String _queueKey = 'offline_item_queue_v1';

  final IItemRepository _itemRepository;
  final Connectivity _connectivity;
  final FirebaseStorage _firebaseStorage;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final ValueNotifier<List<ItemModel>> pendingItemsNotifier =
      ValueNotifier<List<ItemModel>>([]);

  bool _isSyncing = false;

  DraftAndSyncService({
    required IItemRepository itemRepository,
    Connectivity? connectivity,
    FirebaseStorage? firebaseStorage,
  })  : _itemRepository = itemRepository,
        _connectivity = connectivity ?? Connectivity(),
        _firebaseStorage = firebaseStorage ?? FirebaseStorage.instance {
    _initQueueAndListeners();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    pendingItemsNotifier.dispose();
  }

  Future<void> _initQueueAndListeners() async {
    await refreshPendingItems();

    // Listen to network changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any(
        (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
      );
      if (isConnected) {
        debugPrint('[DraftAndSyncService] Network restored. Triggering offline sync queue...');
        syncPendingQueue();
      }
    });

    // Check once at startup
    final initialResults = await _connectivity.checkConnectivity();
    if (initialResults.any((r) => r != ConnectivityResult.none)) {
      syncPendingQueue();
    }
  }

  // ==========================================
  // DRAFT MANAGEMENT
  // ==========================================

  Future<void> saveDraft(ReportDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(draft.toMap());
      await prefs.setString(_draftKey, jsonStr);
      debugPrint('[DraftAndSyncService] Draft saved successfully (Step ${draft.step})');
    } catch (e) {
      debugPrint('[DraftAndSyncService] Error saving draft: $e');
    }
  }

  Future<ReportDraft?> getDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_draftKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ReportDraft.fromMap(map);
    } catch (e) {
      debugPrint('[DraftAndSyncService] Error loading draft: $e');
      return null;
    }
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      debugPrint('[DraftAndSyncService] Draft cleared');
    } catch (e) {
      debugPrint('[DraftAndSyncService] Error clearing draft: $e');
    }
  }

  // ==========================================
  // OFFLINE QUEUE & AUTO-RETRY
  // ==========================================

  Future<void> queueItemForUpload({
    required ItemModel item,
    required List<String> localImagePaths,
    String? hiddenDetail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = await _getRawQueue(prefs);

      final queuedReport = QueuedItemReport(
        id: item.id.isNotEmpty ? item.id : const Uuid().v4(),
        item: item.copyWith(isPendingSync: true),
        localImagePaths: localImagePaths,
        hiddenDetail: hiddenDetail,
        createdAt: DateTime.now(),
      );

      currentQueue.add(queuedReport);
      await _saveRawQueue(prefs, currentQueue);
      await refreshPendingItems();

      debugPrint('[DraftAndSyncService] Queued offline item: ${queuedReport.id}');

      // Attempt immediate upload in case we are actually connected
      syncPendingQueue();
    } catch (e) {
      debugPrint('[DraftAndSyncService] Failed to queue item: $e');
    }
  }

  Future<void> refreshPendingItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = await _getRawQueue(prefs);
      pendingItemsNotifier.value = queue.map((q) => q.item).toList();
    } catch (_) {}
  }

  Future<void> syncPendingQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = await _getRawQueue(prefs);

      if (queue.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('[DraftAndSyncService] Processing ${queue.length} queued items...');

      final List<QueuedItemReport> remaining = [];

      for (final report in queue) {
        try {
          // 1. Upload photos if needed
          final List<String> uploadedUrls = [];
          for (final path in report.localImagePaths) {
            final file = File(path);
            if (await file.exists()) {
              final fileName = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.jpg';
              final ref = _firebaseStorage.ref().child('items/${report.id}/$fileName');
              final uploadTask = await ref.putFile(
                file,
                SettableMetadata(contentType: 'image/jpeg'),
              );
              final downloadUrl = await uploadTask.ref.getDownloadURL();
              uploadedUrls.add(downloadUrl);
            } else if (path.startsWith('http')) {
              uploadedUrls.add(path);
            }
          }

          // 2. Prepare item with uploaded URLs and isPendingSync: false
          final finalItem = report.item.copyWith(
            imageUrls: uploadedUrls.isNotEmpty ? uploadedUrls : report.item.imageUrls,
            isPendingSync: false,
          );

          // 3. Write to Firestore
          await _itemRepository.createItem(
            finalItem,
            hiddenDetail: report.hiddenDetail,
          );

          debugPrint('[DraftAndSyncService] Successfully synced offline item: ${report.id}');
        } catch (e) {
          debugPrint('[DraftAndSyncService] Error syncing item ${report.id}: $e. Keeping in retry queue.');
          remaining.add(report);
        }
      }

      await _saveRawQueue(prefs, remaining);
      await refreshPendingItems();
    } finally {
      _isSyncing = false;
    }
  }

  Future<List<QueuedItemReport>> _getRawQueue(SharedPreferences prefs) async {
    final list = prefs.getStringList(_queueKey) ?? [];
    return list.map((jsonStr) {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return QueuedItemReport.fromMap(map);
    }).toList();
  }

  Future<void> _saveRawQueue(
    SharedPreferences prefs,
    List<QueuedItemReport> queue,
  ) async {
    final list = queue.map((q) => jsonEncode(q.toMap())).toList();
    await prefs.setStringList(_queueKey, list);
  }
}

final draftAndSyncServiceProvider = Provider<DraftAndSyncService>((ref) {
  final itemRepository = ref.watch(itemRepositoryProvider);
  final service = DraftAndSyncService(itemRepository: itemRepository);
  ref.onDispose(() => service.dispose());
  return service;
});

final pendingSyncItemsProvider =
    ValueListenableProvider<List<ItemModel>>((ref) {
  final service = ref.watch(draftAndSyncServiceProvider);
  return service.pendingItemsNotifier;
});
