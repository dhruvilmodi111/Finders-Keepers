import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/services/demo_data_seeder.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider);

    final displayName = user?.displayName ?? 'VIT Student';
    final email = user?.email ?? 'Not signed in';
    final isVit = user?.isVitStudent ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: user?.photoUrl != null
                        ? NetworkImage(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 56,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  if (isVit)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.accentAmber,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.verified,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: theme.textTheme.displayMedium?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Settings List
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Dark Mode'),
                    trailing: Switch(
                      value: themeMode == ThemeMode.dark,
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('VIT Verification Status'),
                    trailing: Chip(
                      label: Text(
                        isVit ? 'VIT Student Verified' : 'Guest / Unverified',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: isVit
                          ? AppColors.primaryTealContainer
                          : AppColors.accentAmberContainer,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Campus Guidelines'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Demo Data & Testing Card
            Card(
              margin: EdgeInsets.zero,
              color: AppColors.primaryTeal.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.primaryTeal.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.accentAmberDark,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Campus Demo & Testing Tools',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Populate realistic VIT campus lost & found items, matching pairs, and claims for testing Smart Match and Heatmap.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final seeder = ref.read(demoDataSeederProvider);
                              final count = await seeder.seedCampusDemoData();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🌱 Seeded $count campus items & matching claims!'),
                                    backgroundColor: AppColors.primaryTeal,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryTeal,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Seed Data'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final seeder = ref.read(demoDataSeederProvider);
                            await seeder.clearDemoData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🧹 Cleared campus demo items.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sign Out Card
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.statusLost),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.statusLost, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) {
                    context.goNamed(RouteNames.login);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
