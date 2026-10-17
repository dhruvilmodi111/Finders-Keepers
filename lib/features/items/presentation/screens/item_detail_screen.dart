import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/draft_and_sync_service.dart';
import '../../../../core/widgets/pending_sync_badge.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../claims/domain/models/claim_model.dart';
import '../../../claims/presentation/controllers/claim_controller.dart';
import '../../../claims/presentation/screens/handover_scanner_screen.dart';
import '../../../claims/presentation/widgets/claim_verification_sheet.dart';
import '../../../claims/presentation/widgets/handover_qr_modal.dart';
import '../../domain/models/item_model.dart';
import '../controllers/item_controller.dart';
import '../widgets/possible_matches_banner.dart';
import '../widgets/status_timeline.dart';

class ItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const ItemDetailScreen({
    super.key,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    // Check offline pending sync queue first
    final pendingItems = ref.watch(pendingSyncItemsProvider);
    final pendingMatch = pendingItems.where((i) => i.id == itemId);
    if (pendingMatch.isNotEmpty) {
      return _buildContent(context, ref, pendingMatch.first, currentUser?.id, isPending: true);
    }

    // Otherwise load from Firestore
    final itemAsync = ref.watch(itemDetailProvider(itemId));

    return itemAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: ItemCardSkeleton()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Failed to load item: $err')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('This item no longer exists.')),
          );
        }
        return _buildContent(context, ref, item, currentUser?.id, isPending: item.isPendingSync);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ItemModel item,
    String? currentUserId, {
    required bool isPending,
  }) {
    final theme = Theme.of(context);
    final isOwner = currentUserId != null && currentUserId == item.ownerId;
    final hasImages = item.imageUrls.isNotEmpty;

    // Check if current user has an active claim on this item
    final claimsAsync = ref.watch(claimsForItemStreamProvider(item.id));
    final userClaim = claimsAsync.asData?.value.where((c) => c.claimerId == currentUserId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title.isNotEmpty ? item.title : 'Item Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Header
            Hero(
              tag: 'item_image_${item.id}',
              child: Container(
                height: 280,
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHighest,
                child: hasImages
                    ? Image.network(
                        item.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                      )
                    : _buildPlaceholder(theme),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row
                  Row(
                    children: [
                      StatusBadge(status: item.status),
                      const SizedBox(width: 8),
                      Chip(label: Text(item.category)),
                      const Spacer(),
                      if (isPending) const PendingSyncBadge(),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    item.title,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Location label
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.accentAmberDark,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.location.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SMART MATCH: Possible Matches within 500m & last 7 days
                  PossibleMatchesBanner(item: item),

                  // STATUS TIMELINE: (lost -> found -> claimed -> returned)
                  StatusTimeline(currentStatus: item.status),
                  const SizedBox(height: 24),

                  // Description
                  Text('Description', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    item.description.isNotEmpty
                        ? item.description
                        : 'No additional description provided.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // Mini Map Preview (~100m approximate)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Approximate Location', style: theme.textTheme.titleMedium),
                      const Text(
                        '(~100m radius)',
                        style: TextStyle(fontSize: 12, color: AppColors.primaryTeal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            item.location.latitude != 0.0
                                ? item.location.latitude
                                : 12.9698,
                            item.location.longitude != 0.0
                                ? item.location.longitude
                                : 79.1559,
                          ),
                          initialZoom: 16.5,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.vit.finderskeepers',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  item.location.latitude != 0.0
                                      ? item.location.latitude
                                      : 12.9698,
                                  item.location.longitude != 0.0
                                      ? item.location.longitude
                                      : 79.1559,
                                ),
                                width: 44,
                                height: 44,
                                child: const Icon(
                                  Icons.location_pin,
                                  size: 40,
                                  color: AppColors.statusLost,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Privacy Notice: In-App Only, No Email/Phone exposed
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.shield_outlined, size: 16, color: AppColors.primaryTeal),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All ownership checks and QR code handovers are conducted securely in-app without sharing contact information.',
                            style: TextStyle(fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ==========================================
                  // INTERACTIVE ACTIONS & HANDOVER
                  // ==========================================

                  // Case 1: Current user is the owner/finder of this item
                  if (isOwner) ...[
                    if (item.status == ItemStatus.claimed) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HandoverScannerScreen(itemId: item.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan Handover QR Code from Claimer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentAmber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ] else if (item.status == ItemStatus.returned) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.statusReturned.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.statusReturned.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle_rounded, color: AppColors.statusReturned, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Handover completed! This item has been safely returned to its owner.',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.person_outline, color: AppColors.primaryTeal),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You reported this item. Review incoming claims in your Claims Inbox.',
                                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]
                  // Case 2: Current user is a claimer who has already submitted a claim
                  else if (userClaim != null) ...[
                    if (userClaim.status == ClaimStatus.approved && item.status == ItemStatus.claimed) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => HandoverQrModal(claim: userClaim),
                            );
                          },
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Show Handover QR Code to Finder'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusFound,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ] else if (userClaim.status == ClaimStatus.pending) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmberContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accentAmberDark.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.pending_actions_rounded, color: AppColors.accentAmberDark),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your ownership claim is pending review by the finder. You will receive an in-app QR code once approved.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (item.status == ItemStatus.returned) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.statusReturned.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle_rounded, color: AppColors.statusReturned),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This item was handed over and returned!',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]
                  // Case 3: Current user has not claimed this item yet
                  else ...[
                    if (item.status == ItemStatus.returned) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.statusReturned.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Item has already been returned to its owner.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else if (item.status == ItemStatus.claimed) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.statusClaimed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'A claim is currently approved and pending handover.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else ...[
                      // "This is mine" Verification Trigger
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => ClaimVerificationSheet(item: item),
                            );
                          },
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text(
                            'This is mine',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 64,
        color: theme.colorScheme.primary.withOpacity(0.4),
      ),
    );
  }
}
