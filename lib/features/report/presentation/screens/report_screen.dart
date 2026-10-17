import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/services/draft_and_sync_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../items/data/repositories/item_repository.dart';
import '../../../items/domain/models/item_model.dart';
import '../widgets/map_location_picker.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  int _currentStep = 0;
  final _picker = ImagePicker();

  // Step 1: Type, Category, Photos
  ItemType _itemType = ItemType.lost;
  String _selectedCategory = 'Electronics';
  final List<String> _localImagePaths = [];
  bool _isCompressingImage = false;

  // Step 2: Title, Description, Location
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  ItemLocation _location = const ItemLocation(
    latitude: AppConstants.defaultLatitude,
    longitude: AppConstants.defaultLongitude,
    label: 'Anna Auditorium, VIT',
  );

  // Step 3: Verification (for FOUND items)
  final _hiddenDetailController = TextEditingController();

  bool _isSubmitting = false;
  bool _hasCheckedDraft = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForDraft();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _hiddenDetailController.dispose();
    super.dispose();
  }

  // ==========================================
  // DRAFT LOGIC
  // ==========================================

  Future<void> _checkForDraft() async {
    if (_hasCheckedDraft) return;
    _hasCheckedDraft = true;

    final draftService = ref.read(draftAndSyncServiceProvider);
    final draft = await draftService.getDraft();

    if (draft != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Found a saved draft. Resume where you left off?'),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Resume',
            textColor: AppColors.accentAmber,
            onPressed: () => _applyDraft(draft),
          ),
        ),
      );
    }
  }

  void _applyDraft(ReportDraft draft) {
    setState(() {
      _currentStep = draft.step;
      _itemType = draft.type;
      _selectedCategory = draft.category;
      _localImagePaths.clear();
      _localImagePaths.addAll(draft.localImagePaths);
      _titleController.text = draft.title;
      _descController.text = draft.description;
      _location = ItemLocation(
        latitude: draft.latitude,
        longitude: draft.longitude,
        label: draft.locationLabel,
      );
      _hiddenDetailController.text = draft.hiddenDetail;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft restored successfully.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveCurrentDraft() async {
    final draftService = ref.read(draftAndSyncServiceProvider);
    final draft = ReportDraft(
      step: _currentStep,
      type: _itemType,
      category: _selectedCategory,
      localImagePaths: List.from(_localImagePaths),
      title: _titleController.text,
      description: _descController.text,
      latitude: _location.latitude,
      longitude: _location.longitude,
      locationLabel: _location.label,
      hiddenDetail: _hiddenDetailController.text,
      updatedAt: DateTime.now(),
    );
    await draftService.saveDraft(draft);
  }

  Future<void> _discardDraft() async {
    final draftService = ref.read(draftAndSyncServiceProvider);
    await draftService.clearDraft();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft discarded')),
      );
      Navigator.of(context).pop();
    }
  }

  // ==========================================
  // IMAGE PICKER & COMPRESSION
  // ==========================================

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isCompressingImage = true);

      // Compress via ImagePicker parameters: max 1200x1200px and 75% quality
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        setState(() {
          _localImagePaths.add(pickedFile.path);
        });
        _saveCurrentDraft();
      }
    } catch (e) {
      debugPrint('[ReportScreen] Image pick error: $e');
    } finally {
      if (mounted) setState(() => _isCompressingImage = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _localImagePaths.removeAt(index);
    });
    _saveCurrentDraft();
  }

  // ==========================================
  // LOCATION PICKER MODAL
  // ==========================================

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<ItemLocation>(
      MaterialPageRoute(
        builder: (context) => MapLocationPickerModal(initialLocation: _location),
      ),
    );

    if (result != null) {
      setState(() {
        _location = result;
      });
      _saveCurrentDraft();
    }
  }

  // ==========================================
  // SUBMISSION & OFFLINE QUEUING
  // ==========================================

  Future<void> _submitReport() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item title in Step 2')),
      );
      setState(() => _currentStep = 1);
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    final ownerId = currentUser?.id ?? 'vit_guest';

    setState(() => _isSubmitting = true);

    // Compute SHA-256 hash for hidden detail if found item
    String hiddenHash = '';
    final secret = _hiddenDetailController.text.trim();
    if (_itemType == ItemType.found && secret.isNotEmpty) {
      hiddenHash = sha256.convert(utf8.encode(secret.toLowerCase())).toString();
    }

    final item = ItemModel(
      id: const Uuid().v4(),
      type: _itemType,
      title: _titleController.text.trim(),
      category: _selectedCategory,
      description: _descController.text.trim(),
      imageUrls: const [],
      location: _location,
      status: _itemType == ItemType.found ? ItemStatus.found : ItemStatus.lost,
      ownerId: ownerId,
      hiddenDetailHash: hiddenHash,
      createdAt: DateTime.now(),
      isPendingSync: false,
    );

    final draftService = ref.read(draftAndSyncServiceProvider);
    final itemRepo = ref.read(itemRepositoryProvider);

    try {
      // Attempt online creation
      await itemRepo.createItem(
        item,
        hiddenDetail: secret.isNotEmpty ? secret : null,
      );

      // Trigger photo sync if any local photos
      if (_localImagePaths.isNotEmpty) {
        await draftService.queueItemForUpload(
          item: item,
          localImagePaths: _localImagePaths,
          hiddenDetail: secret.isNotEmpty ? secret : null,
        );
      }

      await draftService.clearDraft();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_itemType == ItemType.found ? "Found" : "Lost"} item posted! Checking for smart matches...',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.statusFound,
            duration: const Duration(seconds: 4),
          ),
        );
        // Navigate directly to item detail so the user sees the "Possible matches" banner!
        context.pushReplacementNamed(
          RouteNames.itemDetail,
          pathParameters: {'id': item.id},
        );
      }
    } catch (e) {
      debugPrint('[ReportScreen] Network submission failed: $e. Queuing offline report.');

      // Queue offline for auto-retry
      await draftService.queueItemForUpload(
        item: item.copyWith(isPendingSync: true),
        localImagePaths: _localImagePaths,
        hiddenDetail: secret.isNotEmpty ? secret : null,
      );

      await draftService.clearDraft();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are offline. Report saved and queued with "Pending Sync" badge!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.accentAmberDark,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==========================================
  // BUILD UI
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Discard Draft',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Discard Draft?'),
                  content: const Text('This will delete all progress on this report.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Keep Editing'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _discardDraft();
                      },
                      child: const Text(
                        'Discard',
                        style: TextStyle(color: AppColors.statusLost),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepTapped: (step) {
          setState(() => _currentStep = step);
          _saveCurrentDraft();
        },
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
            _saveCurrentDraft();
          } else {
            _submitReport();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
            _saveCurrentDraft();
          } else {
            Navigator.of(context).pop();
          }
        },
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : details.onStepContinue,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isLastStep ? 'Submit Report' : 'Next Step'),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          // ==========================================
          // STEP 1: Type, Category, Compressed Photos
          // ==========================================
          Step(
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            title: const Text('Basics'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What are you reporting?',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Lost vs Found Toggle
                SegmentedButton<ItemType>(
                  segments: const [
                    ButtonSegment(
                      value: ItemType.lost,
                      icon: Icon(Icons.search_rounded),
                      label: Text('I Lost Something'),
                    ),
                    ButtonSegment(
                      value: ItemType.found,
                      icon: Icon(Icons.volunteer_activism_rounded),
                      label: Text('I Found Something'),
                    ),
                  ],
                  selected: {_itemType},
                  onSelectionChanged: (Set<ItemType> newSelection) {
                    setState(() {
                      _itemType = newSelection.first;
                    });
                    _saveCurrentDraft();
                  },
                ),
                const SizedBox(height: 24),

                // Category Chips
                Text('Category', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.categories
                      .where((cat) => cat != 'All')
                      .map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat);
                          _saveCurrentDraft();
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Photos Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Photos (Compressed)', style: theme.textTheme.titleMedium),
                    if (_isCompressingImage)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Add clear photos to help with identification. Images are automatically compressed to save data.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 12),

                // Photo Action Buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('From Gallery'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Photo Thumbnails
                if (_localImagePaths.isNotEmpty)
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _localImagePaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final path = _localImagePaths[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(path),
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ==========================================
          // STEP 2: Title, Description, Pick Location on Map
          // ==========================================
          Step(
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            title: const Text('Details'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  onChanged: (_) => _saveCurrentDraft(),
                  decoration: const InputDecoration(
                    labelText: 'Item Title *',
                    hintText: 'e.g. Blue Dell Laptop Charger, VIT ID Card',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  onChanged: (_) => _saveCurrentDraft(),
                  decoration: const InputDecoration(
                    labelText: 'Description & Details',
                    hintText: 'Color, brand, identifying marks, condition, when noticed...',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.description_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Location Picker Card
                Text('Location on Campus', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.accentAmberContainer,
                      child: Icon(Icons.location_on, color: AppColors.accentAmberDark),
                    ),
                    title: Text(
                      _location.label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_location.latitude.toStringAsFixed(4)}, ${_location.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: OutlinedButton(
                      onPressed: _openMapPicker,
                      child: const Text('Pick on Map'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // STEP 3: Secret Verification (Hidden Detail for FOUND)
          // ==========================================
          Step(
            isActive: _currentStep >= 2,
            state: StepState.indexed,
            title: const Text('Security'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_itemType == ItemType.found) ...[
                  // Prominent info box with user-requested note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryTeal.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.security_rounded, color: AppColors.primaryTeal, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Private Verification Detail',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '"Only the real owner should know this"',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Keep a unique identifier hidden from the public feed (e.g. lock-screen photo, specific scratch, serial number, keychain mascot). When a student claims this item, they must answer this detail to prove ownership.',
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hiddenDetailController,
                    onChanged: (_) => _saveCurrentDraft(),
                    decoration: const InputDecoration(
                      labelText: 'Hidden Secret Detail *',
                      hintText: 'e.g. Sticker of Batman on back, 500 Rs in back pocket',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      helperText: 'Protected by SHA-256 hash & Firestore security rules.',
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.accentAmberDark.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info_outline, color: AppColors.accentAmberDark, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Lost Item Verification Tip',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.accentAmberDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'If someone finds this item, you will be able to verify and approve their handover securely through the app.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Review Summary Card
                Text('Report Summary', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(_itemType == ItemType.found ? 'FOUND' : 'LOST'),
                              backgroundColor: _itemType == ItemType.found
                                  ? AppColors.primaryTealContainer
                                  : AppColors.accentAmberContainer,
                            ),
                            const SizedBox(width: 8),
                            Chip(label: Text(_selectedCategory)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _titleController.text.isNotEmpty
                              ? _titleController.text
                              : '(No title entered)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _location.label,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (_localImagePaths.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_localImagePaths.length} photo(s) ready to upload',
                            style: const TextStyle(fontSize: 12, color: AppColors.primaryTeal),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
