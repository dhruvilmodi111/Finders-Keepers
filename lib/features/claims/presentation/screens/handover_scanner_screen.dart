import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../controllers/claim_controller.dart';

class HandoverScannerScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String? claimId;

  const HandoverScannerScreen({
    super.key,
    required this.itemId,
    this.claimId,
  });

  @override
  ConsumerState<HandoverScannerScreen> createState() =>
      _HandoverScannerScreenState();
}

class _HandoverScannerScreenState extends ConsumerState<HandoverScannerScreen> {
  late MobileScannerController _cameraController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawVal = barcodes.first.rawValue;
    if (rawVal == null || rawVal.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final map = jsonDecode(rawVal) as Map<String, dynamic>;
      final scannedItemId = map['itemId'] as String? ?? '';
      final scannedClaimId = map['claimId'] as String? ?? widget.claimId ?? '';
      final token = map['token'] as String? ?? '';

      if (scannedItemId != widget.itemId) {
        throw Exception('QR Code belongs to a different item.');
      }

      final success = await ref
          .read(claimControllerProvider.notifier)
          .completeHandover(
            claimId: scannedClaimId,
            itemId: widget.itemId,
            scannedToken: token,
          );

      if (mounted) {
        if (success) {
          _cameraController.stop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: AppColors.statusFound, size: 28),
                  SizedBox(width: 10),
                  Text('Handover Complete!'),
                ],
              ),
              content: const Text(
                'The item status has been permanently updated to "Returned". Thank you for returning this lost item to its rightful owner!',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // dismiss dialog
                    Navigator.of(context).pop(true); // exit scanner screen with success
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid or expired QR code. Verification failed.'),
              backgroundColor: AppColors.statusLost,
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) setState(() => _isProcessing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan Error: $e'),
            backgroundColor: AppColors.statusLost,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Handover QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onBarcodeDetected,
          ),

          // Viewfinder Overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accentAmber, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),

          // Guidance Banner
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Align the claimer\'s QR code within the frame to finalize handover.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accentAmber),
              ),
            ),
        ],
      ),
    );
  }
}
