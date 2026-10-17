import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../features/items/data/repositories/item_repository.dart';
import '../../features/items/domain/models/item_model.dart';
import '../constants/app_constants.dart';

class MatchedItem {
  final ItemModel item;
  final double distanceMeters;
  final double matchScore; // 0.0 to 1.0

  const MatchedItem({
    required this.item,
    required this.distanceMeters,
    required this.matchScore,
  });
}

class SmartMatchService {
  final FirebaseFirestore _firestore;

  SmartMatchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<MatchedItem>> findPossibleMatches(ItemModel targetItem) async {
    final oppositeType =
        targetItem.type == ItemType.lost ? ItemType.found : ItemType.lost;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    try {
      // Query opposite type in same category from the last 7 days
      final snapshot = await _firestore
          .collection(AppConstants.itemsCollection)
          .where('type', isEqualTo: oppositeType.name)
          .where('category', isEqualTo: targetItem.category)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();

      final List<MatchedItem> matches = [];
      const distanceCalc = Distance();
      final targetLatLng = LatLng(
        targetItem.location.latitude != 0.0
            ? targetItem.location.latitude
            : AppConstants.defaultLatitude,
        targetItem.location.longitude != 0.0
            ? targetItem.location.longitude
            : AppConstants.defaultLongitude,
      );

      for (final doc in snapshot.docs) {
        if (doc.id == targetItem.id) continue;

        final candidate = ItemModel.fromFirestore(doc);
        final candidateLatLng = LatLng(
          candidate.location.latitude != 0.0
              ? candidate.location.latitude
              : AppConstants.defaultLatitude,
          candidate.location.longitude != 0.0
              ? candidate.location.longitude
              : AppConstants.defaultLongitude,
        );

        // Distance in meters
        final distanceMeters =
            distanceCalc.as(LengthUnit.Meter, targetLatLng, candidateLatLng);

        // Filter: must be within 500 meters
        if (distanceMeters <= 500) {
          // Calculate similarity score
          double score = 0.5; // Base category & type match

          // Distance factor (closer = higher score up to +0.3)
          score += (1.0 - (distanceMeters / 500.0)) * 0.3;

          // Keyword match in title/description (+0.2)
          final targetWords = targetItem.title
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .where((w) => w.length > 2);
          final candidateText =
              '${candidate.title} ${candidate.description}'.toLowerCase();

          for (final word in targetWords) {
            if (candidateText.contains(word)) {
              score += 0.1;
              break;
            }
          }

          matches.add(
            MatchedItem(
              item: candidate,
              distanceMeters: distanceMeters,
              matchScore: score.clamp(0.0, 1.0),
            ),
          );
        }
      }

      // Sort by highest match score, then closest distance
      matches.sort((a, b) {
        final scoreComp = b.matchScore.compareTo(a.matchScore);
        if (scoreComp != 0) return scoreComp;
        return a.distanceMeters.compareTo(b.distanceMeters);
      });

      return matches;
    } catch (e) {
      return [];
    }
  }
}

final smartMatchServiceProvider = Provider<SmartMatchService>((ref) {
  return SmartMatchService();
});

final possibleMatchesProvider =
    FutureProvider.autoDispose.family<List<MatchedItem>, ItemModel>(
  (ref, targetItem) {
    final service = ref.watch(smartMatchServiceProvider);
    return service.findPossibleMatches(targetItem);
  },
);
