import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/services/draft_and_sync_service.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/fade_slide_entrance.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../items/presentation/controllers/item_controller.dart';
import '../../../items/presentation/widgets/item_card.dart';

class MyItemsScreen extends ConsumerWidget {
  const MyItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser?.id ?? '';

    final myItemsAsync = ref.watch(userItemsStreamProvider(userId));
    final pendingItems = ref.watch(pendingSyncItemsProvider);

    // Filter pending items authored by current user
    final userPendingItems = pendingItems
        .where((i) => i.ownerId == userId || userId.isEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reported Items'),
      ),
      body: myItemsAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 4,
          itemBuilder: (_, __) => const ItemCardSkeleton(),
        ),
        error: (err, _) => ErrorStateWidget(
          title: 'Could not load your items',
          message: 'Unable to retrieve items from Firestore. Check your connection.',
          onRetry: () => ref.invalidate(userItemsStreamProvider(userId)),
        ),
        data: (remoteItems) {
          final allMyItems = [...userPendingItems, ...remoteItems];

          if (allMyItems.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.inventory_2_outlined,
              title: 'No items reported yet',
              message: 'Items you report as lost or found will appear here so you can track claims and handovers.',
              buttonText: 'Report an Item',
              onButtonPressed: () => context.pushNamed(RouteNames.reportItem),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userItemsStreamProvider(userId));
              await ref.read(draftAndSyncServiceProvider).syncPendingQueue();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: allMyItems.length,
              itemBuilder: (context, index) {
                return FadeSlideEntrance(
                  delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
                  child: ItemCard(item: allMyItems[index]),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.reportItem),
        backgroundColor: AppColors.accentAmber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Report New'),
      ),
    );
  }
}
