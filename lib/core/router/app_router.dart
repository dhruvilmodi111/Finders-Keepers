import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/claims/presentation/screens/claims_inbox_screen.dart';
import '../../features/claims/presentation/screens/handover_scanner_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/items/presentation/screens/item_detail_screen.dart';
import '../../features/map/presentation/screens/lost_heatmap_screen.dart';
import '../../features/map/presentation/screens/map_view_screen.dart';
import '../../features/my_items/presentation/screens/my_items_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/report/presentation/screens/report_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateStreamProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // While checking auth on initial splash screen, do not interrupt
      if (state.matchedLocation == '/') return null;

      final isLoggedIn = authState.asData?.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      final protectedRoutes = [
        '/report',
        '/my-items',
        '/claims',
        '/profile',
        '/scanner',
      ];

      final isProtected = protectedRoutes.any(
        (route) => state.matchedLocation.startsWith(route),
      );

      // Redirect unauthenticated users away from protected screens to login
      if (!isLoggedIn && isProtected) {
        return '/login';
      }

      // If user is already logged in and navigates to /login, take them home
      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/items/:id',
        name: RouteNames.itemDetail,
        builder: (context, state) {
          final itemId = state.pathParameters['id'] ?? '';
          return ItemDetailScreen(itemId: itemId);
        },
      ),
      GoRoute(
        path: '/report',
        name: RouteNames.reportItem,
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: '/map',
        name: RouteNames.mapView,
        builder: (context, state) => const MapViewScreen(),
      ),
      GoRoute(
        path: '/heatmap',
        name: RouteNames.lostHeatmap,
        builder: (context, state) => const LostHeatmapScreen(),
      ),
      GoRoute(
        path: '/my-items',
        name: RouteNames.myItems,
        builder: (context, state) => const MyItemsScreen(),
      ),
      GoRoute(
        path: '/claims',
        name: RouteNames.claimsInbox,
        builder: (context, state) => const ClaimsInboxScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: RouteNames.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/scanner/:itemId',
        name: RouteNames.handoverScanner,
        builder: (context, state) {
          final itemId = state.pathParameters['itemId'] ?? '';
          return HandoverScannerScreen(itemId: itemId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri.toString()}'),
      ),
    ),
  );
});
