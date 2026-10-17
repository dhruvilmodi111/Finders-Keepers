import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/claims/domain/models/claim_model.dart';
import '../../features/items/domain/models/item_model.dart';
import '../constants/app_constants.dart';

class DemoDataSeeder {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DemoDataSeeder({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String _hashSecret(String secret) {
    return sha256.convert(utf8.encode(secret.trim().toLowerCase())).toString();
  }

  /// Seeds realistic VIT campus lost and found items, matching pairs, and claims
  Future<int> seedCampusDemoData() async {
    final currentUserId = _auth.currentUser?.uid ?? 'vit_demo_user';
    final otherUserId = 'vit_student_21bce1089';
    final now = DateTime.now();

    final batch = _firestore.batch();
    int count = 0;

    // 1. Matched Pair 1: MacBook Air (Lost) & MacBook Charger (Found) at Silver Jubilee Tower (SJT)
    final lostMacbookId = 'demo_item_sjt_macbook';
    final foundChargerId = 'demo_item_sjt_charger';

    final lostMacbook = ItemModel(
      id: lostMacbookId,
      type: ItemType.lost,
      title: 'Space Grey MacBook Air M2',
      category: 'Electronics',
      description: 'Left on desk row 3 in SJT 412 during evening lab. Has a GitHub Octocat sticker.',
      imageUrls: [
        'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=600&q=80',
      ],
      location: const ItemLocation(
        latitude: 12.9723,
        longitude: 79.1624,
        label: 'Silver Jubilee Tower (SJT), 4th Floor Lab',
      ),
      status: ItemStatus.lost,
      ownerId: currentUserId,
      hiddenDetailHash: '',
      createdAt: now.subtract(const Duration(hours: 14)),
      isPendingSync: false,
    );

    final foundCharger = ItemModel(
      id: foundChargerId,
      type: ItemType.found,
      title: 'Apple 67W USB-C Charger & Braided Cable',
      category: 'Electronics',
      description: 'Found plugged into wall socket behind the podium in SJT 4th floor.',
      imageUrls: [
        'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=600&q=80',
      ],
      location: const ItemLocation(
        latitude: 12.9725,
        longitude: 79.1626,
        label: 'Silver Jubilee Tower (SJT), Floor 4',
      ),
      status: ItemStatus.found,
      ownerId: otherUserId,
      hiddenDetailHash: _hashSecret('braided white cable with black ink dot'),
      createdAt: now.subtract(const Duration(hours: 4)),
      isPendingSync: false,
    );

    // 2. Matched Pair 2: VIT Student ID Card (Lost) & ID Badge (Found) near Food Mall / Gazebo
    final lostIdCardId = 'demo_item_foodmall_id';
    final foundIdCardId = 'demo_item_gazebo_id';

    final lostIdCard = ItemModel(
      id: lostIdCardId,
      type: ItemType.lost,
      title: 'VIT Student ID Card & Green Lanyard',
      category: 'Cards & IDs',
      description: 'Registration number 22BCE**** in green VIT lanyard. Dropped between Food Mall and Gazebo.',
      imageUrls: [
        'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&w=600&q=80',
      ],
      location: const ItemLocation(
        latitude: 12.9692,
        longitude: 79.1565,
        label: 'Food Mall & Gazebo Walkway',
      ),
      status: ItemStatus.lost,
      ownerId: otherUserId,
      hiddenDetailHash: '',
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      isPendingSync: false,
    );

    final foundIdCard = ItemModel(
      id: foundIdCardId,
      type: ItemType.found,
      title: 'Student ID Card & Hostel Room Key',
      category: 'Cards & IDs',
      description: 'Found lying on wooden bench outside Food Mall facing Gazebo.',
      imageUrls: [],
      location: const ItemLocation(
        latitude: 12.9694,
        longitude: 79.1568,
        label: 'Gazebo Seating Area',
      ),
      status: ItemStatus.found,
      ownerId: currentUserId,
      hiddenDetailHash: _hashSecret('Block Q room 312 brass key attached'),
      createdAt: now.subtract(const Duration(hours: 18)),
      isPendingSync: false,
    );

    // 3. Central Library Hotspot item
    final libraryFlask = ItemModel(
      id: 'demo_item_library_flask',
      type: ItemType.lost,
      title: 'Matte Blue Hydro Flask (32oz)',
      category: 'Bottles & Containers',
      description: 'Left on second-floor cubicle study desk in Central Library. Has Naruto sticker.',
      imageUrls: [
        'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
      ],
      location: const ItemLocation(
        latitude: 12.9706,
        longitude: 79.1578,
        label: 'Central Library, 2nd Floor Quiet Zone',
      ),
      status: ItemStatus.lost,
      ownerId: currentUserId,
      hiddenDetailHash: '',
      createdAt: now.subtract(const Duration(days: 2)),
      isPendingSync: false,
    );

    // 4. Technology Tower (TT) Hotspot item
    final ttWatch = ItemModel(
      id: 'demo_item_tt_watch',
      type: ItemType.lost,
      title: 'Titan Octane Chronograph Watch',
      category: 'Accessories',
      description: 'Silver stainless steel watch left next to keyboard in TT 204 smart classroom.',
      imageUrls: [
        'https://images.unsplash.com/photo-1524805444758-089113d48a6d?auto=format&fit=crop&w=600&q=80',
      ],
      location: const ItemLocation(
        latitude: 12.9712,
        longitude: 79.1585,
        label: 'Technology Tower (TT), Room 204',
      ),
      status: ItemStatus.lost,
      ownerId: otherUserId,
      hiddenDetailHash: '',
      createdAt: now.subtract(const Duration(days: 3)),
      isPendingSync: false,
    );

    // 5. SMV Block Item: Status = Claimed (Ready for QR Scanner Demo!)
    final smvAirpodsId = 'demo_item_smv_airpods';
    final smvAirpods = ItemModel(
      id: smvAirpodsId,
      type: ItemType.found,
      title: 'Boat Airdopes 141 ANC Case',
      category: 'Electronics',
      description: 'Found inside SMV ground floor seminar hall after guest lecture.',
      imageUrls: [
        'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=600&q=80',
      ],
      location: const ItemLocation(
        latitude: 12.9688,
        longitude: 79.1542,
        label: 'SMV Block, Seminar Hall 1',
      ),
      status: ItemStatus.claimed,
      ownerId: currentUserId,
      hiddenDetailHash: _hashSecret('left earbud has a small scratch on mesh'),
      createdAt: now.subtract(const Duration(days: 1)),
      isPendingSync: false,
    );

    // 6. PRP Block Item: Status = Returned (Shows Full Timeline Completion!)
    final prpCalculatorId = 'demo_item_prp_calc';
    final prpCalculator = ItemModel(
      id: prpCalculatorId,
      type: ItemType.found,
      title: 'Casio FX-991CW Scientific Calculator',
      category: 'Electronics',
      description: 'Found on desk in PRP Block exam hall 3. Handover verified via QR code.',
      imageUrls: [
        'https://images.unsplash.com/photo-1594980596870-8aa52a78d8cd?auto=format&fit=crop&w=600&q=80',
      ],
      location: const ItemLocation(
        latitude: 12.9701,
        longitude: 79.1610,
        label: 'PRP Block, Room 302',
      ),
      status: ItemStatus.returned,
      ownerId: currentUserId,
      hiddenDetailHash: _hashSecret('name Modi written on battery lid in blue marker'),
      createdAt: now.subtract(const Duration(days: 4)),
      isPendingSync: false,
    );

    final itemsToSeed = [
      lostMacbook,
      foundCharger,
      lostIdCard,
      foundIdCard,
      libraryFlask,
      ttWatch,
      smvAirpods,
      prpCalculator,
    ];

    for (final item in itemsToSeed) {
      final docRef = _firestore.collection(AppConstants.itemsCollection).doc(item.id);
      batch.set(docRef, item.toFirestore());
      count++;
    }

    // Seed Demo Claims
    // A. Pending Claim on foundIdCard (For Finder Inbox review)
    final pendingClaim = ClaimModel(
      id: 'demo_claim_pending_id',
      itemId: foundIdCardId,
      claimerId: otherUserId,
      claimerEmail: 'student.22bce@vitstudent.ac.in',
      claimerName: 'Ananya Sharma',
      claimerAlias: 'VIT Student #B4E1',
      answers: {
        'Brand / Manufacturer / Issuing Body': 'VIT University Vellore',
        'Distinguishing marks, scratches, or contents': 'Block Q hostel room 312 key attached to brass ring',
        'Private verification detail': 'Block Q room 312 brass key attached',
      },
      status: ClaimStatus.pending,
      createdAt: now.subtract(const Duration(hours: 6)),
    );
    batch.set(
      _firestore.collection(AppConstants.claimsCollection).doc(pendingClaim.id),
      pendingClaim.toFirestore(),
    );
    count++;

    // B. Approved Claim with one-time QR token on smvAirpods (Ready for mobile scanner demo!)
    final approvedClaim = ClaimModel(
      id: 'demo_claim_approved_airpods',
      itemId: smvAirpodsId,
      claimerId: otherUserId,
      claimerEmail: 'student.21bce@vitstudent.ac.in',
      claimerName: 'Rohan Verma',
      claimerAlias: 'VIT Student #A8F3',
      answers: {
        'Brand / Manufacturer / Issuing Body': 'boAt Lifestyle',
        'Color, material, or model variation': 'Matte Charcoal Black',
        'Private verification detail': 'left earbud has a small scratch on mesh',
      },
      status: ClaimStatus.approved,
      handoverToken: 'HANDOVER_DEMO_QR_TOKEN_8923',
      approvedAt: now.subtract(const Duration(hours: 2)),
      createdAt: now.subtract(const Duration(hours: 12)),
    );
    batch.set(
      _firestore.collection(AppConstants.claimsCollection).doc(approvedClaim.id),
      approvedClaim.toFirestore(),
    );
    count++;

    // C. Returned Claim on PRP Calculator (Completed timeline)
    final returnedClaim = ClaimModel(
      id: 'demo_claim_returned_calc',
      itemId: prpCalculatorId,
      claimerId: otherUserId,
      claimerEmail: 'student.20bce@vitstudent.ac.in',
      claimerName: 'Dhruv Patel',
      claimerAlias: 'VIT Student #C1D9',
      answers: {
        'Brand / Manufacturer / Issuing Body': 'Casio Japan',
        'Private verification detail': 'name Modi written on battery lid in blue marker',
      },
      status: ClaimStatus.approved,
      approvedAt: now.subtract(const Duration(days: 2)),
      returnedAt: now.subtract(const Duration(days: 1)),
      createdAt: now.subtract(const Duration(days: 3)),
    );
    batch.set(
      _firestore.collection(AppConstants.claimsCollection).doc(returnedClaim.id),
      returnedClaim.toFirestore(),
    );
    count++;

    await batch.commit();
    debugPrint('[DemoDataSeeder] Successfully seeded $count campus items and claims!');
    return count;
  }

  /// Clears demo items from Firestore
  Future<void> clearDemoData() async {
    final demoItemIds = [
      'demo_item_sjt_macbook',
      'demo_item_sjt_charger',
      'demo_item_foodmall_id',
      'demo_item_gazebo_id',
      'demo_item_library_flask',
      'demo_item_tt_watch',
      'demo_item_smv_airpods',
      'demo_item_prp_calc',
    ];

    final demoClaimIds = [
      'demo_claim_pending_id',
      'demo_claim_approved_airpods',
      'demo_claim_returned_calc',
    ];

    final batch = _firestore.batch();
    for (final id in demoItemIds) {
      batch.delete(_firestore.collection(AppConstants.itemsCollection).doc(id));
    }
    for (final id in demoClaimIds) {
      batch.delete(_firestore.collection(AppConstants.claimsCollection).doc(id));
    }

    await batch.commit();
    debugPrint('[DemoDataSeeder] Cleared demo items and claims.');
  }
}

final demoDataSeederProvider = Provider<DemoDataSeeder>((ref) {
  return DemoDataSeeder();
});
