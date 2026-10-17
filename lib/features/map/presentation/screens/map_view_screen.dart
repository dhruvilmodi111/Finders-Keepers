import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/services/draft_and_sync_service.dart';
import '../../../../core/widgets/pending_sync_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../items/domain/models/item_model.dart';
import '../../../items/presentation/controllers/item_controller.dart';

class MapItemCluster {
  final LatLng center;
  final List<ItemModel> items;

  const MapItemCluster({
    required this.center,
    required this.items,
  });

  bool get isSingle => items.length == 1;
  ItemModel get firstItem => items.first;

  bool get hasOnlyLost => items.every((i) => i.type == ItemType.lost);
  bool get hasOnlyFound => items.every((i) => i.type == ItemType.found);
}

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key});

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  final MapController _mapController = MapController();
  ItemType? _typeFilter; // null = All, ItemType.lost = Lost only, ItemType.found = Found only

  // Round coordinate to 3 decimal places (~100m resolution)
  double _roundTo100m(double val) => (val * 1000).round() / 1000;

  List<MapItemCluster> _buildClusters(List<ItemModel> allItems) {
    // 1. Filter by user selection
    final filtered = _typeFilter == null
        ? allItems
        : allItems.where((i) => i.type == _typeFilter).toList();

    // 2. Group by approximate ~100m rounded coordinates
    final Map<String, List<ItemModel>> grouped = {};

    for (final item in filtered) {
      // Default to campus coordinates if lat/lng is 0
      final lat = item.location.latitude != 0.0
          ? item.location.latitude
          : AppConstants.defaultLatitude;
      final lng = item.location.longitude != 0.0
          ? item.location.longitude
          : AppConstants.defaultLongitude;

      final approxLat = _roundTo100m(lat);
      final approxLng = _roundTo100m(lng);
      final key = '${approxLat.toStringAsFixed(3)}_${approxLng.toStringAsFixed(3)}';

      grouped.putIfAbsent(key, () => []).add(item);
    }

    // 3. Create cluster objects
    return grouped.entries.map((entry) {
      final parts = entry.key.split('_');
      final clusterLat = double.parse(parts[0]);
      final clusterLng = double.parse(parts[1]);

      return MapItemCluster(
        center: LatLng(clusterLat, clusterLng),
        items: entry.value,
      );
    }).toList();
  }

  // ==========================================
  // BOTTOM SHEET PREVIEWS
  // ==========================================

  void _showSingleItemPreview(BuildContext context, ItemModel item) {
    final theme = Theme.of(context);
    final isFound = item.type == ItemType.found;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Badges & Privacy banner
              Row(
                children: [
                  StatusBadge(status: item.status),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(item.category),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Spacer(),
                  if (item.isPendingSync) const PendingSyncBadge(compact: true),
                ],
              ),
              const SizedBox(height: 10),

              // Approximate location disclaimer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: AppColors.primaryTeal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Approximate area (~100m) • ${item.location.label}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Thumbnail and Title Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'item_image_${item.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 76,
                        height: 76,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: item.imageUrls.isNotEmpty
                            ? Image.network(
                                item.imageUrls.first,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_outlined,
                                  color: AppColors.primaryTeal,
                                ),
                              )
                            : const Icon(
                                Icons.image_outlined,
                                color: AppColors.primaryTeal,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (item.description.isNotEmpty)
                          Text(
                            item.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.lightTextSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // View Full Details Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.pushNamed(
                      RouteNames.itemDetail,
                      pathParameters: {'id': item.id},
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(isFound ? 'View & Claim Item' : 'View Lost Item Details'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClusterPreview(BuildContext context, MapItemCluster cluster) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cluster Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cluster.items.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cluster.items.length} Items in this ~100m area',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          cluster.firstItem.location.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // Items List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cluster.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = cluster.items[index];
                    final isFound = item.type == ItemType.found;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: item.imageUrls.isNotEmpty
                              ? Image.network(
                                  item.imageUrls.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.image_outlined,
                                    color: isFound ? AppColors.statusFound : AppColors.statusLost,
                                  ),
                                )
                              : Icon(
                                  Icons.image_outlined,
                                  color: isFound ? AppColors.statusFound : AppColors.statusLost,
                                ),
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Row(
                        children: [
                          StatusBadge(status: item.status, compact: true),
                          const SizedBox(width: 6),
                          Text(item.category, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        context.pushNamed(
                          RouteNames.itemDetail,
                          pathParameters: {'id': item.id},
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // BUILD SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(itemsStreamProvider(const ItemFilterState(type: null, category: 'All')));
    final pendingItems = ref.watch(pendingSyncItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_fire_department_rounded, color: AppColors.statusLost),
            tooltip: 'Lost Heatmap',
            onPressed: () => context.pushNamed(RouteNames.lostHeatmap),
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Re-center Map',
            onPressed: () {
              _mapController.move(
                const LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude),
                16.5,
              );
            },
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load map data: $err')),
        data: (remoteItems) {
          final allItems = [...pendingItems, ...remoteItems];
          final clusters = _buildClusters(allItems);

          return Stack(
            children: [
              // OpenStreetMap Canvas
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(
                    AppConstants.defaultLatitude,
                    AppConstants.defaultLongitude,
                  ),
                  initialZoom: 16.5,
                  minZoom: 14.0,
                  maxZoom: 18.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.vit.finderskeepers',
                  ),

                  // Approximate Clustered Markers Layer
                  MarkerLayer(
                    markers: clusters.map((cluster) {
                      if (cluster.isSingle) {
                        final item = cluster.firstItem;
                        final isFound = item.type == ItemType.found;
                        final color = isFound ? AppColors.statusFound : AppColors.statusLost;

                        return Marker(
                          point: cluster.center,
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => _showSingleItemPreview(context, item),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFound ? Icons.check : Icons.help_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Multi-Item Cluster Marker
                        Color clusterColor;
                        if (cluster.hasOnlyFound) {
                          clusterColor = AppColors.statusFound;
                        } else if (cluster.hasOnlyLost) {
                          clusterColor = AppColors.statusLost;
                        } else {
                          clusterColor = AppColors.primaryTeal;
                        }

                        return Marker(
                          point: cluster.center,
                          width: 48,
                          height: 48,
                          child: GestureDetector(
                            onTap: () => _showClusterPreview(context, cluster),
                            child: Container(
                              decoration: BoxDecoration(
                                color: clusterColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentAmberLight,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: clusterColor.withOpacity(0.45),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${cluster.items.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    }).toList(),
                  ),
                ],
              ),

              // Top Map Filter Bar (All / Lost Only / Found Only)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    // Filter Chips Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ChoiceChip(
                            label: const Text('All Items'),
                            selected: _typeFilter == null,
                            onSelected: (selected) {
                              if (selected) setState(() => _typeFilter = null);
                            },
                          ),
                          ChoiceChip(
                            avatar: const Icon(Icons.circle, size: 10, color: AppColors.statusLost),
                            label: const Text('Lost Only'),
                            selected: _typeFilter == ItemType.lost,
                            onSelected: (selected) {
                              if (selected) setState(() => _typeFilter = ItemType.lost);
                            },
                          ),
                          ChoiceChip(
                            avatar: const Icon(Icons.circle, size: 10, color: AppColors.statusFound),
                            label: const Text('Found Only'),
                            selected: _typeFilter == ItemType.found,
                            onSelected: (selected) {
                              if (selected) setState(() => _typeFilter = ItemType.found);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Privacy Banner (~100m approximate locations)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.privacy_tip_outlined, size: 13, color: AppColors.primaryTeal),
                          SizedBox(width: 6),
                          Text(
                            'Approximate locations (~100m) for campus security & privacy',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Legend
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.statusLost,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('Lost', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.statusFound,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('Found', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
