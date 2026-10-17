import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/fade_slide_entrance.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/claim_model.dart';
import '../controllers/claim_controller.dart';
import '../widgets/handover_qr_modal.dart';
import 'handover_scanner_screen.dart';

class ClaimsInboxScreen extends ConsumerStatefulWidget {
  const ClaimsInboxScreen({super.key});

  @override
  ConsumerState<ClaimsInboxScreen> createState() => _ClaimsInboxScreenState();
}

class _ClaimsInboxScreenState extends ConsumerState<ClaimsInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser?.id ?? '';

    final incomingClaimsAsync = ref.watch(claimsForFinderStreamProvider(userId));
    final myClaimsAsync = ref.watch(claimsByClaimerStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claims & Handovers'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Incoming Claims (Finder)'),
            Tab(text: 'My Claims (Owner)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Incoming Claims for Items Found by Current User
          incomingClaimsAsync.when(
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => const ItemCardSkeleton(),
            ),
            error: (err, _) => ErrorStateWidget(
              title: 'Could not load incoming claims',
              message: 'Unable to retrieve claims submitted by other students. Pull or tap to retry.',
              onRetry: () => ref.invalidate(claimsForFinderStreamProvider(userId)),
            ),
            data: (claims) {
              if (claims.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.inbox_outlined,
                  title: 'No claims yet',
                  message: 'When students submit ownership answers for items you reported finding, they will appear here.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: claims.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return FadeSlideEntrance(
                    delay: Duration(milliseconds: 50 * index.clamp(0, 8)),
                    child: _buildFinderClaimCard(context, claims[index]),
                  );
                },
              );
            },
          ),

          // Tab 2: My Claims Filed by Current User
          myClaimsAsync.when(
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => const ItemCardSkeleton(),
            ),
            error: (err, _) => ErrorStateWidget(
              title: 'Could not load your claims',
              message: 'Unable to retrieve claims you submitted. Pull or tap to retry.',
              onRetry: () => ref.invalidate(claimsByClaimerStreamProvider(userId)),
            ),
            data: (claims) {
              if (claims.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.checklist_rtl_rounded,
                  title: 'No claims submitted',
                  message: 'When you find your lost property on the feed, tap "This is mine" to start ownership verification.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: claims.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return FadeSlideEntrance(
                    delay: Duration(milliseconds: 50 * index.clamp(0, 8)),
                    child: _buildClaimerClaimCard(context, claims[index]),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FINDER CLAIM CARD
  // ==========================================

  Widget _buildFinderClaimCard(BuildContext context, ClaimModel claim) {
    final theme = Theme.of(context);
    final answers = claim.answers;
    final q1 = answers['question1'] as String? ?? 'Category Details';
    final a1 = answers['answer1'] as String? ?? 'No answer provided';
    final q2 = answers['question2'] as String? ?? 'Secret Detail';
    final a2 = answers['answer2'] as String? ?? 'No answer provided';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Item Title & Claim Status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.itemTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Claimed by: ${claim.claimerAlias}',
                        style: const TextStyle(fontSize: 12, color: AppColors.primaryTeal),
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(claim.status),
              ],
            ),
            const Divider(height: 20),

            // Question 1 & Answer
            Text(
              q1,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(a1, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 12),

            // Question 2 & Answer (Secret detail)
            Text(
              q2,
              style: const TextStyle(fontSize: 12, color: AppColors.accentAmberDark, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(a2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 16),

            // Action Buttons based on status
            if (claim.status == ClaimStatus.pending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(claimControllerProvider.notifier).rejectClaim(claim.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Claim rejected.')),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusLost,
                        side: const BorderSide(color: AppColors.statusLost),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await ref.read(claimControllerProvider.notifier).approveClaim(
                              claimId: claim.id,
                              itemId: claim.itemId,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Claim approved! Ready for QR handover scan.'),
                              backgroundColor: AppColors.statusFound,
                            ),
                          );
                        }
                      },
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ] else if (claim.status == ClaimStatus.approved) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HandoverScannerScreen(
                          itemId: claim.itemId,
                          claimId: claim.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan Handover QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentAmber,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ] else if (claim.status == ClaimStatus.returned) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusReturned.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Handover Complete • Item Successfully Returned',
                    style: TextStyle(
                      color: AppColors.statusReturned,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CLAIMER CLAIM CARD (With One-Time QR)
  // ==========================================

  Widget _buildClaimerClaimCard(BuildContext context, ClaimModel claim) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    claim.itemTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _buildStatusPill(claim.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Filed on: ${claim.createdAt.day}/${claim.createdAt.month}/${claim.createdAt.year}',
              style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 14),

            if (claim.status == ClaimStatus.pending) ...[
              const Text(
                'Waiting for the finder to review your answers in their inbox.',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ] else if (claim.status == ClaimStatus.approved) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusFound.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.statusFound.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your ownership claim was verified and approved by the finder!',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => HandoverQrModal(claim: claim),
                          );
                        },
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Show Handover QR Code'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (claim.status == ClaimStatus.returned) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusReturned.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Item Collected • Returned to You',
                    style: TextStyle(
                      color: AppColors.statusReturned,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ] else if (claim.status == ClaimStatus.rejected) ...[
              const Text(
                'Your claim could not be verified by the finder. If this is truly your item, please review the listing details or contact campus security.',
                style: TextStyle(fontSize: 12, color: AppColors.statusLost),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(ClaimStatus status) {
    Color color;
    String label;
    switch (status) {
      case ClaimStatus.approved:
        color = AppColors.statusClaimed;
        label = 'APPROVED';
        break;
      case ClaimStatus.rejected:
        color = AppColors.statusLost;
        label = 'REJECTED';
        break;
      case ClaimStatus.returned:
        color = AppColors.statusReturned;
        label = 'RETURNED';
        break;
      case ClaimStatus.pending:
      default:
        color = AppColors.accentAmberDark;
        label = 'PENDING';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
