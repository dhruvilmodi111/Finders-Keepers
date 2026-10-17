import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../items/domain/models/item_model.dart';
import '../../../items/presentation/controllers/item_controller.dart';

class CampusHotspot {
  final String id;
  final String name;
  final LatLng coordinates;
  final List<ItemModel> lostItems;
  final Map<String, int> categoryCounts;

  const CampusHotspot({
    required this.id,
    required this.name,
    required this.coordinates,
    required this.lostItems,
    required this.categoryCounts,
  });

  int get count => lostItems.length;

  String get topCategory {
    if (categoryCounts.isEmpty) return 'Various';
    final sorted = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}

class LostHeatmapScreen extends ConsumerStatefulWidget {
  const LostHeatmapScreen({super.key});

  @override
  ConsumerState<LostHeatmapScreen> createState() => _LostHeatmapScreenState();
}

class _LostHeatmapScreenState extends ConsumerState<LostHeatmapScreen> {
  final MapController _mapController = MapController();
  int _selectedTimeFilterDays = 0; // 0 = All Time, 7 = Last 7 Days, 30 = Last 30 Days
  String _selectedCategory = 'All';

  static const List<Map<String, dynamic>> defaultCampusZones = [
    {
      'id': 'sjt',
      'name': 'Silver Jubilee Tower (SJT)',
      'coords': LatLng(12.9723, 79.1624),
    },
    {
      'id': 'tt',
      'name': 'Technology Tower (TT)',
      'coords': LatLng(12.9712, 79.1585),
    },
    {
      'id': 'anna_aud',
      'name': 'Anna Auditorium',
      'coords': LatLng(12.9698, 79.1559),
    },
    {
      'id': 'library',
      'name': 'Central Library',
      'coords': LatLng(12.9706, 79.1578),
    },
    {
      'id': 'food_mall',
      'name': 'Food Mall & Gazebo',
      'coords': LatLng(12.9692, 79.1565),
    },
    {
      'id': 'smv',
      'name': 'SMV Block',
      'coords': LatLng(12.9688, 79.1542),
    },
    {
      'id': 'prp',
      'name': 'PRP Block',
      'coords': LatLng(12.9701, 79.1610),
    },
    {
      'id': 'stadium',
      'name': 'Outdoor Stadium & Gym',
      'coords': LatLng(12.9675, 79.1570),
    },
  ];

  List<CampusHotspot> _calculateHotspots(List<ItemModel> allItems) {
    const distanceCalc = Distance();
    final now = DateTime.now();

    // 1. Filter lost items by time and category
    final lostItems = allItems.where((item) {
      if (item.type != ItemType.lost) return false;

      // Time filter
      if (_selectedTimeFilterDays > 0) {
        final diff = now.difference(item.createdAt).inDays;
        if (diff > _selectedTimeFilterDays) return false;
      }

      // Category filter
      if (_selectedCategory != 'All' && item.category != _selectedCategory) {
        return false;
      }

      return true;
    }).toList();

    // 2. Assign lost items to closest campus zone (within 200m)
    final List<CampusHotspot> hotspots = [];

    for (final zone in defaultCampusZones) {
      final zoneCoords = zone['coords'] as LatLng;
      final matchedItems = <ItemModel>[];
      final catCounts = <String, int>{};

      for (final item in lostItems) {
        final itemCoords = LatLng(
          item.location.latitude != 0.0 ? item.location.latitude : AppConstants.defaultLatitude,
          item.location.longitude != 0.0 ? item.location.longitude : AppConstants.defaultLongitude,
        );

        final dist = distanceCalc.as(LengthUnit.Meter, zoneCoords, itemCoords);
        final labelLower = item.location.label.toLowerCase();
        final nameLower = (zone['name'] as String).toLowerCase();

        if (dist <= 220 || labelLower.contains(nameLower.split(' ').first)) {
          matchedItems.add(item);
          catCounts[item.category] = (catCounts[item.category] ?? 0) + 1;
        }
      }

      hotspots.add(
        CampusHotspot(
          id: zone['id'] as String,
          name: zone['name'] as String,
          coordinates: zoneCoords,
          lostItems: matchedItems,
          categoryCounts: catCounts,
        ),
      );
    }

    // Sort by most incidents
    hotspots.sort((a, b) => b.count.compareTo(a.count));
    return hotspots;
  }

  void _showHotspotDetails(CampusHotspot hotspot) {
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
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

              // Title & Risk level
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.statusLost.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.statusLost,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotspot.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${hotspot.count} Lost Item Reports • Most frequent: ${hotspot.topCategory}',
                          style: const TextStyle(fontSize: 12, color: AppColors.statusLost),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Breakdown Chips
              if (hotspot.categoryCounts.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: hotspot.categoryCounts.entries.map((e) {
                    return Chip(
                      label: Text('${e.key}: ${e.value}'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      labelStyle: const TextStyle(fontSize: 11),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              const Divider(height: 1),
              const SizedBox(height: 8),

              // Recent Lost Items in this hotspot
              Text(
                'Recent Lost Items in this Zone',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              Expanded(
                child: hotspot.lostItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No lost items reported for the selected filter period.',
                        style: TextStyle(color: AppColors.lightTextSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: hotspot.lostItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = hotspot.lostItems[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${item.category} • ${item.location.label}',
                            style: const TextStyle(fontSize: 11),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(
      itemsStreamProvider(const ItemFilterState(type: ItemType.lost, category: 'All')),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.local_fire_department_rounded, color: AppColors.statusLost, size: 24),
            SizedBox(width: 8),
            Text('Campus Lost Heatmap'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Campus Center',
            onPressed: () {
              _mapController.move(
                const LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude),
                16.2,
              );
            },
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading heatmap: $err')),
        data: (allItems) {
          final hotspots = _calculateHotspots(allItems);

          // Find max incident count for heat scale normalization
          final maxCount = hotspots.isNotEmpty ? (hotspots.first.count > 0 ? hotspots.first.count : 1) : 1;

          return Stack(
            children: [
              // OpenStreetMap with Heatmap Circles
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(
                    AppConstants.defaultLatitude,
                    AppConstants.defaultLongitude,
                  ),
                  initialZoom: 16.2,
                  minZoom: 14.5,
                  maxZoom: 18.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.vit.finderskeepers',
                  ),

                  // Concentric Heat Intensity Circles Layer
                  CircleLayer(
                    circles: hotspots.expand((hotspot) {
                      final intensity = (hotspot.count / maxCount).clamp(0.1, 1.0);

                      // Outer glowing halo
                      final outerCircle = CircleMarker(
                        point: hotspot.coordinates,
                        radius: 70 + (intensity * 40),
                        useRadiusInMeter: true,
                        color: AppColors.statusLost.withOpacity(0.14 * intensity),
                        borderColor: Colors.transparent,
                        borderStrokeWidth: 0,
                      );

                      // Middle heat aura
                      final middleCircle = CircleMarker(
                        point: hotspot.coordinates,
                        radius: 40 + (intensity * 25),
                        useRadiusInMeter: true,
                        color: AppColors.accentAmber.withOpacity(0.28 * intensity),
                        borderColor: Colors.transparent,
                        borderStrokeWidth: 0,
                      );

                      // Core thermal epicenter
                      final innerCircle = CircleMarker(
                        point: hotspot.coordinates,
                        radius: 20 + (intensity * 15),
                        useRadiusInMeter: true,
                        color: AppColors.statusLost.withOpacity(0.65 * intensity),
                        borderColor: Colors.white.withOpacity(0.4),
                        borderStrokeWidth: 1.5,
                      );

                      return [outerCircle, middleCircle, innerCircle];
                    }).toList(),
                  ),

                  // Hotspot Marker Pins Layer
                  MarkerLayer(
                    markers: hotspots.map((hotspot) {
                      final hasItems = hotspot.count > 0;

                      return Marker(
                        point: hotspot.coordinates,
                        width: 52,
                        height: 52,
                        child: GestureDetector(
                          onTap: () {
                            _mapController.move(hotspot.coordinates, 17.2);
                            _showHotspotDetails(hotspot);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: hasItems ? AppColors.statusLost : Colors.grey[700],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: hasItems
                                      ? AppColors.statusLost.withOpacity(0.5)
                                      : Colors.black26,
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                Text(
                                  '${hotspot.count}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Top Filters (Time & Category)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.94),
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
                            label: const Text('All Time'),
                            selected: _selectedTimeFilterDays == 0,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedTimeFilterDays = 0);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Last 30 Days'),
                            selected: _selectedTimeFilterDays == 30,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedTimeFilterDays = 30);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Last 7 Days'),
                            selected: _selectedTimeFilterDays == 7,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedTimeFilterDays = 7);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Hotspot Ranking Drawer / Quick Summary
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.statusLost),
                              SizedBox(width: 6),
                              Text(
                                'Top Lost Hotspot',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          Text(
                            hotspots.isNotEmpty ? '${hotspots.first.name} (${hotspots.first.count})' : 'Campus',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.statusLost,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap any hotspot circle or flame icon on the map to see the full breakdown and reported items in that zone.',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
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
