import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../items/domain/models/item_model.dart';

class CampusLandmark {
  final String name;
  final LatLng coordinates;

  const CampusLandmark(this.name, this.coordinates);
}

class MapLocationPickerModal extends StatefulWidget {
  final ItemLocation initialLocation;

  const MapLocationPickerModal({
    super.key,
    required this.initialLocation,
  });

  @override
  State<MapLocationPickerModal> createState() => _MapLocationPickerModalState();
}

class _MapLocationPickerModalState extends State<MapLocationPickerModal> {
  late MapController _mapController;
  late LatLng _selectedLatLng;
  late TextEditingController _labelController;

  static const List<CampusLandmark> vitLandmarks = [
    CampusLandmark('Anna Auditorium', LatLng(12.9698, 79.1559)),
    CampusLandmark('Technology Tower (TT)', LatLng(12.9712, 79.1585)),
    CampusLandmark('Silver Jubilee Tower (SJT)', LatLng(12.9723, 79.1624)),
    CampusLandmark('Main Library', LatLng(12.9706, 79.1578)),
    CampusLandmark('Food Mall', LatLng(12.9692, 79.1565)),
    CampusLandmark('SMV Block', LatLng(12.9688, 79.1542)),
    CampusLandmark('PRP Block', LatLng(12.9701, 79.1610)),
    CampusLandmark('Outdoor Stadium', LatLng(12.9675, 79.1570)),
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLatLng = LatLng(
      widget.initialLocation.latitude != 0.0
          ? widget.initialLocation.latitude
          : AppConstants.defaultLatitude,
      widget.initialLocation.longitude != 0.0
          ? widget.initialLocation.longitude
          : AppConstants.defaultLongitude,
    );
    _labelController = TextEditingController(text: widget.initialLocation.label);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _onLandmarkSelected(CampusLandmark landmark) {
    setState(() {
      _selectedLatLng = landmark.coordinates;
      _labelController.text = landmark.name;
    });
    _mapController.move(_selectedLatLng, 17.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Item Location'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(
                ItemLocation(
                  latitude: _selectedLatLng.latitude,
                  longitude: _selectedLatLng.longitude,
                  label: _labelController.text.trim().isNotEmpty
                      ? _labelController.text.trim()
                      : 'Campus Landmark',
                ),
              );
            },
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Landmarks Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2),
                  child: Text(
                    'Quick Campus Landmarks',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: vitLandmarks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final l = vitLandmarks[index];
                      final isSelected = _selectedLatLng.latitude == l.coordinates.latitude &&
                          _selectedLatLng.longitude == l.coordinates.longitude;

                      return ActionChip(
                        avatar: Icon(
                          Icons.place,
                          size: 14,
                          color: isSelected ? Colors.white : AppColors.primaryTeal,
                        ),
                        backgroundColor: isSelected
                            ? AppColors.primaryTeal
                            : theme.colorScheme.surface,
                        label: Text(
                          l.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onPressed: () => _onLandmarkSelected(l),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Interactive Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLatLng,
                    initialZoom: 16.5,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLatLng = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.vit.finderskeepers',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLatLng,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_pin,
                            size: 48,
                            color: AppColors.statusLost,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Map Hint overlay
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.touch_app_outlined, size: 16, color: AppColors.primaryTeal),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap anywhere on the campus map to drop or adjust pin',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Location Label Field
          Container(
            padding: const EdgeInsets.all(16.0),
            color: theme.colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Location Name / Specific Spot',
                    hintText: 'e.g. SJT 4th Floor Lab 412, Gazebo benches',
                    prefixIcon: Icon(Icons.edit_location_alt_outlined),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Coordinates: ${_selectedLatLng.latitude.toStringAsFixed(5)}, ${_selectedLatLng.longitude.toStringAsFixed(5)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.lightTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
