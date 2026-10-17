import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/services/demo_data_seeder.dart';
import '../../../../core/services/draft_and_sync_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/fade_slide_entrance.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../items/domain/models/item_model.dart';
import '../../../items/presentation/controllers/item_controller.dart';
import '../../../items/presentation/widgets/item_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final currentFilter = ref.read(itemFilterProvider);
        ref.read(itemFilterProvider.notifier).state = currentFilter.copyWith(
          type: _tabController.index == 0 ? ItemType.lost : ItemType.found,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        context.pushNamed(RouteNames.mapView);
        break;
      case 2:
        context.pushNamed(RouteNames.myItems);
        break;
      case 3:
        context.pushNamed(RouteNames.claimsInbox);
        break;
      case 4:
        context.pushNamed(RouteNames.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final filter = ref.watch(itemFilterProvider);
    final itemsAsync = ref.watch(activeFilteredItemsProvider);
    final pendingItems = ref.watch(pendingSyncItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.travel_explore_rounded,
              color: AppColors.accentAmber,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              AppConstants.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_fire_department_rounded, color: AppColors.statusLost),
            tooltip: 'Lost Heatmap',
            onPressed: () {
              context.pushNamed(RouteNames.lostHeatmap);
            },
          ),
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              context.pushNamed(RouteNames.claimsInbox);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(122),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(itemFilterProvider.notifier).state =
                        ref.read(itemFilterProvider).copyWith(searchQuery: val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search items, locations, brands...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(itemFilterProvider.notifier).state =
                                  ref.read(itemFilterProvider).copyWith(searchQuery: '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),

              // Category Chips Horizontal List
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: AppConstants.categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = AppConstants.categories[index];
                    final isSelected = cat == filter.category;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(itemFilterProvider.notifier).state =
                              ref.read(itemFilterProvider).copyWith(category: cat);
                        }
                      },
                    );
                  },
                ),
              ),

              // Tabs: Lost vs Found
              TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                tabs: const [
                  Tab(text: 'Lost Items'),
                  Tab(text: 'Found Items'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: itemsAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 6,
          itemBuilder: (_, __) => const ItemCardSkeleton(),
        ),
        error: (err, _) => ErrorStateWidget(
          title: 'Could not load campus feed',
          message: 'Unable to connect to Firestore. If you are offline, cached items will be displayed when available.',
          onRetry: () => ref.invalidate(activeFilteredItemsProvider),
        ),
        data: (remoteItems) {
          final targetType =
              _tabController.index == 0 ? ItemType.lost : ItemType.found;

          // Filter pending items matching current tab and category
          final relevantPending = pendingItems.where((item) {
            final typeMatch = item.type == targetType;
            final catMatch = filter.category == 'All' || item.category == filter.category;
            return typeMatch && catMatch;
          }).toList();

          // Merge pending items at the top
          final allItems = [...relevantPending, ...remoteItems];

          if (allItems.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  EmptyStateWidget(
                    icon: targetType == ItemType.lost
                        ? Icons.search_off_rounded
                        : Icons.inventory_2_outlined,
                    title: 'No ${targetType.name} items found',
                    message: filter.searchQuery.isNotEmpty
                        ? 'No results match "${filter.searchQuery}". Try a different keyword.'
                        : 'Be the first to report a ${targetType.name} item in this category!',
                    buttonText: 'Report Item',
                    onButtonPressed: () => context.pushNamed(RouteNames.reportItem),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final seeder = ref.read(demoDataSeederProvider);
                        final count = await seeder.seedCampusDemoData();
                        ref.invalidate(activeFilteredItemsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🌱 Seeded $count campus items & matching claims!'),
                              backgroundColor: AppColors.primaryTeal,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Seed Campus Demo Data'),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeFilteredItemsProvider);
              await ref.read(draftAndSyncServiceProvider).syncPendingQueue();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: allItems.length,
              itemBuilder: (context, index) {
                return FadeSlideEntrance(
                  delay: Duration(milliseconds: 40 * index.clamp(0, 10)),
                  child: ItemCard(item: allItems[index]),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.pushNamed(RouteNames.reportItem);
        },
        backgroundColor: AppColors.accentAmber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Report Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onBottomNavTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Campus Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'My Items',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Claims',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
