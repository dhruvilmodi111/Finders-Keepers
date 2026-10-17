import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/claim_repository.dart';
import '../../domain/models/claim_model.dart';

final claimRepositoryProvider = Provider<IClaimRepository>((ref) {
  return FirestoreClaimRepository();
});

final claimsForItemStreamProvider =
    StreamProvider.autoDispose.family<List<ClaimModel>, String>((ref, itemId) {
  final repository = ref.watch(claimRepositoryProvider);
  return repository.streamClaimsForItem(itemId);
});

final claimsForFinderStreamProvider =
    StreamProvider.autoDispose.family<List<ClaimModel>, String>((ref, finderUserId) {
  final repository = ref.watch(claimRepositoryProvider);
  return repository.streamClaimsForFinder(finderUserId);
});

final claimsByClaimerStreamProvider =
    StreamProvider.autoDispose.family<List<ClaimModel>, String>((ref, claimerId) {
  final repository = ref.watch(claimRepositoryProvider);
  return repository.streamClaimsByClaimer(claimerId);
});

class ClaimController extends StateNotifier<AsyncValue<void>> {
  final IClaimRepository _repository;

  ClaimController(this._repository) : super(const AsyncValue.data(null));

  Future<String?> submitClaim(ClaimModel claim) async {
    state = const AsyncValue.loading();
    try {
      final claimId = await _repository.submitClaim(claim);
      state = const AsyncValue.data(null);
      return claimId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<String?> approveClaim({
    required String claimId,
    required String itemId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final token = await _repository.approveClaim(
        claimId: claimId,
        itemId: itemId,
      );
      state = const AsyncValue.data(null);
      return token;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> rejectClaim(String claimId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.rejectClaim(claimId: claimId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> completeHandover({
    required String claimId,
    required String itemId,
    required String scannedToken,
  }) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.completeHandoverWithToken(
        claimId: claimId,
        itemId: itemId,
        scannedToken: scannedToken,
      );
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final claimControllerProvider =
    StateNotifierProvider<ClaimController, AsyncValue<void>>((ref) {
  final repository = ref.watch(claimRepositoryProvider);
  return ClaimController(repository);
});
