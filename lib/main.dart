import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/router/route_names.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase & Cloud Firestore offline persistence
  await FirebaseService.initialize();

  runApp(
    const ProviderScope(
      child: FindersKeepersApp(),
    ),
  );
}

class FindersKeepersApp extends ConsumerStatefulWidget {
  const FindersKeepersApp({super.key});

  @override
  ConsumerState<FindersKeepersApp> createState() => _FindersKeepersAppState();
}

class _FindersKeepersAppState extends ConsumerState<FindersKeepersApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initialize(
        onSmartMatchNotificationTapped: (itemId) {
          final router = ref.read(appRouterProvider);
          router.pushNamed(
            RouteNames.itemDetail,
            pathParameters: {'id': itemId},
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      scaffoldMessengerKey: NotificationService.messengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

