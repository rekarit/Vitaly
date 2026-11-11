import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/material_item.dart';
import '../../core/models/slab.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/widgets/stone_image_widget.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// StoneInventory Form Dialog
/// Exact replication of the AppSheet "StoneInventory Form" (Screenshots 3 & 4)
/// Includes live QR generation, auto-calculated Area_sqm, and PrintLabelText.
/// Supports both Add Slab and Edit Slab modes.
/// ──────────────────────────────────────────────────────────────────────────
class SlabFormDialog extends StatefulWidget {
  final MaterialItem initialMaterial;
  final Slab? initialSlab;

  const SlabFormDialog({
    super.key,
    required this.initialMaterial,
    this.initialSlab,
  });

  static Future<Slab?> show(BuildContext context, MaterialItem material, {Slab? initialSlab}) {
    return AdaptiveDialog.show<Slab>(
      context: context,
      isDismissible: false,
      builder: (ctx) => SlabFormDialog(initialMaterial: material, initialSlab: initialSlab),
    );
  }

  @override
  State<SlabFormDialog> createState() => _SlabFormDialogState();
}

class _SlabFormDialogState extends State<SlabFormDialog> {
  late MaterialItem _selectedMaterial;

  // Controllers
  late TextEditingController _slabNoCtrl;
  late TextEditingController _lengthCmCtrl;
  late TextEditingController _widthCmCtrl;
  late TextEditingController _thicknessMmCtrl;
  late TextEditingController _areaSqmCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _batchIdCtrl;
  late TextEditingController _printLabelTextCtrl;
  late TextEditingController _quantityCtrl;

  // Multiple Slabs batch mode
  bool _isMultipleSlabs = false;

  // RackCode & Date
  String _selectedRackCode = 'Warehouse';
  DateTime _receivedDate = DateTime.now();

  // Photo
  Uint8List? _photoBytes;
  String? _photoUrl;
  String? _photoName;

  // Unique InventoryID (2 lowercase letters + 6 digits e.g. ef219868)
  String _inventoryId = '';
  // Live QR Code Payload
  String _qrPayload = '';

  // Availability status (Available / Unavailable)
  SlabStatus _selectedStatus = SlabStatus.available;

  final List<String> _rackOptions = [
    'Showroom',
    'Site delivery',
    'Warehouse',
  ];

  static String generateUniqueInventoryId() {
    final rand = Random();
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    final l1 = letters[rand.nextInt(letters.length)];
    final l2 = letters[rand.nextInt(letters.length)];
    final digits = (100000 + rand.nextInt(900000)).toString();
    return '$l1$l2$digits';
  }

  @override
  void initState() {
    super.initState();
    _selectedMaterial = widget.initialMaterial;

    if (widget.initialSlab != null) {
      final slab = widget.initialSlab!;
      _selectedStatus = slab.status == SlabStatus.unavailable
          ? SlabStatus.unavailable
          : (slab.status == SlabStatus.damaged
              ? SlabStatus.damaged
              : SlabStatus.available);
      _slabNoCtrl = TextEditingController(text: slab.slabNo);
      final double lCm = slab.lengthCm > 0 ? slab.lengthCm : (slab.lengthMm / 10.0);
      final double wCm = slab.widthCm > 0 ? slab.widthCm : (slab.widthMm / 10.0);
      _lengthCmCtrl = TextEditingController(text: lCm % 1 == 0 ? lCm.toInt().toString() : lCm.toStringAsFixed(1));
      _widthCmCtrl = TextEditingController(text: wCm % 1 == 0 ? wCm.toInt().toString() : wCm.toStringAsFixed(1));
      _thicknessMmCtrl = TextEditingController(text: slab.thicknessMm.toInt().toString());
      _areaSqmCtrl = TextEditingController(text: slab.areaSqm.toStringAsFixed(2));
      _notesCtrl = TextEditingController(text: slab.defectNotes ?? '');
      _batchIdCtrl = TextEditingController(text: slab.batchId ?? 'BATCH-${_selectedMaterial.materialCode}-01');
      _printLabelTextCtrl = TextEditingController(text: slab.printLabelText);
      final rawRack = slab.warehouseLocation.trim().toLowerCase();
      if (rawRack == 'showroom') {
        _selectedRackCode = 'Showroom';
      } else if (rawRack.contains('site') || rawRack.contains('delivery')) {
        _selectedRackCode = 'Site delivery';
      } else {
        _selectedRackCode = 'Warehouse';
      }
      _receivedDate = slab.receivedDate;
      _photoBytes = slab.photoBytes ?? _selectedMaterial.imageBytes;
      _photoUrl = slab.photoUrl ?? _selectedMaterial.imageUrl;
      _photoName = _photoBytes != null ? 'slab_photo.png' : (_photoUrl != null ? 'material_photo.png' : null);
      _inventoryId = slab.inventoryId ?? (slab.customQrData ?? generateUniqueInventoryId());
      _qrPayload = slab.qrCode;
    } else {
      final appState = AppStateScope.read(context);
      final nextSlabNo = appState.nextSlabNoForMaterial(_selectedMaterial.materialCode);

      _slabNoCtrl = TextEditingController(text: nextSlabNo);
      _lengthCmCtrl = TextEditingController(text: '280');
      _widthCmCtrl = TextEditingController(text: '160');
      _thicknessMmCtrl = TextEditingController(text: '20');
      _areaSqmCtrl = TextEditingController();
      _notesCtrl = TextEditingController();
      _batchIdCtrl = TextEditingController(text: 'BATCH-${_selectedMaterial.materialCode}-01');
      _printLabelTextCtrl = TextEditingController();
      _photoBytes = _selectedMaterial.imageBytes;
      _photoUrl = _selectedMaterial.imageUrl;
      _photoName = _photoBytes != null ? '${_selectedMaterial.materialCode}_default.png' : (_photoUrl != null ? 'master_image.png' : null);
      _inventoryId = generateUniqueInventoryId();
      _qrPayload = 'https://rekarit.github.io/Vitaly/?material=${_selectedMaterial.materialCode}&slab=$nextSlabNo';
    }

    _quantityCtrl = TextEditingController(text: '20');

    _recomputeFormulas();

    // Listeners for live updates
    _slabNoCtrl.addListener(_recomputeFormulas);
    _lengthCmCtrl.addListener(_recomputeFormulas);
    _widthCmCtrl.addListener(_recomputeFormulas);
    _thicknessMmCtrl.addListener(_recomputeFormulas);
  }

  @override
  void dispose() {
    _slabNoCtrl.dispose();
    _lengthCmCtrl.dispose();
    _widthCmCtrl.dispose();
    _thicknessMmCtrl.dispose();
    _areaSqmCtrl.dispose();
    _notesCtrl.dispose();
    _batchIdCtrl.dispose();
    _printLabelTextCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  void _recomputeFormulas() {
    final length = double.tryParse(_lengthCmCtrl.text.trim()) ?? 0.0;
    final width = double.tryParse(_widthCmCtrl.text.trim()) ?? 0.0;
    final slabNo = _slabNoCtrl.text.trim();

    // Area_sqm formula: (Length_cm * Width_cm) / 10,000
    final area = (length * width) / 10000.0;
    _areaSqmCtrl.text = area > 0 ? area.toStringAsFixed(2) : '0.00';

    // PrintLabelText formula: [SlabNo] · [StoneType] / [MaterialName] · [Finish]
    _printLabelTextCtrl.text =
        '$slabNo · ${_selectedMaterial.stoneType} / ${_selectedMaterial.name.toUpperCase()} · ${_selectedMaterial.finish}';

    // Direct deep-link QR URL to this material tab
    _qrPayload =
        'https://rekarit.github.io/Vitaly/?material=${_selectedMaterial.materialCode}&slab=$slabNo';

    setState(() {});
  }

  void _stepField(TextEditingController controller, double delta, {double min = 0.0}) {
    final current = double.tryParse(controller.text.trim()) ?? 0.0;
    final newVal = (current + delta).clamp(min, 99999.0);
    controller.text = newVal.toInt().toString();
  }

  Future<void> _pickPhoto() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _photoBytes = bytes;
          _photoUrl = null;
          _photoName = file.name;
        });
      }
    } catch (_) {}
  }

  Future<void> _removePhoto() async {
    setState(() {
      _photoBytes = null;
      _photoUrl = null;
      _photoName = null;
    });
  }

  Future<void> _selectReceivedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.colors.primary,
              surface: context.colors.surface,
              onSurface: context.colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _receivedDate = picked;
        _recomputeFormulas();
      });
    }
  }

  bool _isSaving = false;

  void _saveSlab() {
    if (_isSaving) return;
    final colors = context.colors;
    final appState = AppStateScope.read(context);

    // Auto-fill slabNo if user cleared it
    String slabNo = _slabNoCtrl.text.trim();
    if (slabNo.isEmpty) {
      slabNo = appState.nextSlabNoForMaterial(_selectedMaterial.materialCode);
      _slabNoCtrl.text = slabNo;
    }

    double lengthCm = double.tryParse(_lengthCmCtrl.text.trim()) ?? 0.0;
    if (lengthCm <= 0) {
      lengthCm = 280.0;
      _lengthCmCtrl.text = '280';
    }

    double widthCm = double.tryParse(_widthCmCtrl.text.trim()) ?? 0.0;
    if (widthCm <= 0) {
      widthCm = 160.0;
      _widthCmCtrl.text = '160';
    }

    double thicknessMm = double.tryParse(_thicknessMmCtrl.text.trim()) ?? 20.0;
    if (thicknessMm <= 0) {
      thicknessMm = 20.0;
      _thicknessMmCtrl.text = '20';
    }

    // Formula: (Length_cm * Width_cm) / 10,000 = sqm
    final area = (lengthCm * widthCm) / 10000.0;
    final lengthMm = lengthCm * 10.0;
    final widthMm = widthCm * 10.0;
    final thicknessCm = thicknessMm / 10.0;
    _isSaving = true;

    // If Multiple Slabs is checked and adding new slabs (not editing existing)
    if (_isMultipleSlabs && widget.initialSlab == null) {
      final qty = int.tryParse(_quantityCtrl.text.trim()) ?? 1;
      if (qty <= 0) {
        _isSaving = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Quantity must be at least 1'), backgroundColor: colors.error),
        );
        return;
      }

      // Determine starting base number and sequence
      String prefix = '${_selectedMaterial.materialCode}-';
      int startSeq = 1;
      final parts = slabNo.split('-');
      if (parts.length >= 2) {
        prefix = '${parts.sublist(0, parts.length - 1).join('-')}-';
        startSeq = int.tryParse(parts.last) ?? 1;
      }

      final List<Slab> batchSlabs = [];
      for (int i = 0; i < qty; i++) {
        final currentSeq = startSeq + i;
        final currentSlabNo = '$prefix${currentSeq.toString().padLeft(2, "0")}';
        final uniqueInvId = (i == 0 && _inventoryId.isNotEmpty)
            ? _inventoryId
            : generateUniqueInventoryId();
        final currentPrintLabel =
            '$currentSlabNo · ${_selectedMaterial.stoneType} / ${_selectedMaterial.name.toUpperCase()} · ${_selectedMaterial.finish}';
        final qrUrl = 'https://rekarit.github.io/Vitaly/?material=${_selectedMaterial.materialCode}&slab=$currentSlabNo';

        batchSlabs.add(Slab(
          id: currentSlabNo,
          materialId: _selectedMaterial.materialCode,
          slabNo: currentSlabNo,
          bundleNumber: _batchIdCtrl.text.trim().isNotEmpty
              ? _batchIdCtrl.text.trim()
              : 'BND-${_selectedMaterial.materialCode}',
          lengthMm: lengthMm,
          widthMm: widthMm,
          thicknessMm: thicknessMm,
          lengthCm: lengthCm,
          widthCm: widthCm,
          thicknessCm: thicknessCm,
          areaSqm: area,
          netAreaSqm: area,
          status: _selectedStatus,
          warehouseLocation: _selectedRackCode,
          receivedDate: _receivedDate,
          defectNotes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          hasDefect: _notesCtrl.text.trim().isNotEmpty,
          batchId: _batchIdCtrl.text.trim(),
          photoBytes: _photoBytes ?? _selectedMaterial.imageBytes,
          photoUrl: _photoUrl ?? _selectedMaterial.imageUrl,
          inventoryId: uniqueInvId,
          customQrData: qrUrl,
          customPrintLabelText: currentPrintLabel,
        ));
      }

      appState.addSlabs(batchSlabs);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added $qty slabs (${batchSlabs.first.slabNo} - ${batchSlabs.last.slabNo})!'),
          backgroundColor: colors.primary,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(batchSlabs.first);
      return;
    }

    final qrUrl = 'https://rekarit.github.io/Vitaly/?material=${_selectedMaterial.materialCode}&slab=$slabNo';
    final newSlab = Slab(
      id: widget.initialSlab?.id ?? slabNo,
      materialId: _selectedMaterial.materialCode,
      slabNo: slabNo,
      bundleNumber: _batchIdCtrl.text.trim().isNotEmpty
          ? _batchIdCtrl.text.trim()
          : 'BND-${_selectedMaterial.materialCode}',
      lengthMm: lengthMm,
      widthMm: widthMm,
      thicknessMm: thicknessMm,
      lengthCm: lengthCm,
      widthCm: widthCm,
      thicknessCm: thicknessCm,
      areaSqm: area,
      netAreaSqm: area,
      status: _selectedStatus,
      warehouseLocation: _selectedRackCode,
      receivedDate: _receivedDate,
      defectNotes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      hasDefect: _notesCtrl.text.trim().isNotEmpty,
      batchId: _batchIdCtrl.text.trim(),
      photoBytes: _photoBytes ?? _selectedMaterial.imageBytes,
      photoUrl: _photoUrl ?? _selectedMaterial.imageUrl,
      inventoryId: _inventoryId,
      customQrData: qrUrl,
      customPrintLabelText: _printLabelTextCtrl.text.trim(),
    );

    if (widget.initialSlab != null) {
      appState.updateSlabData(newSlab);
    } else {
      appState.addSlab(newSlab);
    }

    Navigator.of(context).pop(newSlab);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBtnTextColor = isDark ? const Color(0xFF111418) : Colors.white;
    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - (isMobile ? 16 : 48)).clamp(220.0, 860.0);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: availableHeight),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Bar (Matching AppSheet Photo 3) ──────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: colors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'StoneInventory Form',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textSecondary,
                          side: BorderSide(color: colors.border),
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF86B9E0), // AppSheet Save Blue accent
                          foregroundColor: const Color(0xFF111418),
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        onPressed: _saveSlab,
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 16),

              // ── Form Body: Exact Field Order as AppSheet Photos 3 & 4 ───
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. MaterialCode* (Dropdown selector with Stone icon)
                      _buildFieldLabel('MaterialCode*', isRequired: true),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: Builder(
                            builder: (context) {
                              final availableMaterials = <String, MaterialItem>{};
                              for (final m in appState.materials) {
                                availableMaterials[m.materialCode] = m;
                              }
                              if (!availableMaterials.containsKey(_selectedMaterial.materialCode)) {
                                availableMaterials[_selectedMaterial.materialCode] = _selectedMaterial;
                              }
                              final currentCode = availableMaterials.containsKey(_selectedMaterial.materialCode)
                                  ? _selectedMaterial.materialCode
                                  : availableMaterials.keys.first;

                              return DropdownButton<String>(
                                value: currentCode,
                                dropdownColor: colors.surface,
                                isExpanded: true,
                                icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                                items: availableMaterials.values.map((m) {
                                  return DropdownMenuItem<String>(
                                    value: m.materialCode,
                                    child: Row(
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 18, color: colors.textSecondary),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '${m.materialCode} - ${m.name.toUpperCase()}',
                                            style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newCode) {
                                  if (newCode != null && availableMaterials.containsKey(newCode)) {
                                    final found = availableMaterials[newCode]!;
                                    setState(() {
                                      _selectedMaterial = found;
                                      _slabNoCtrl.text = appState.nextSlabNoForMaterial(found.materialCode);
                                      _batchIdCtrl.text = 'BATCH-${found.materialCode}-01';
                                      _photoBytes = found.imageBytes;
                                      _photoUrl = found.imageUrl;
                                      _photoName = _photoBytes != null ? '${found.materialCode}_default.png' : (_photoUrl != null ? 'master_image.png' : null);
                                      _recomputeFormulas();
                                    });
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. SlabNo* (Strictly Read-Only & Auto-Generated per ERP rules)
                      _buildStandardField(
                        label: 'SlabNo*',
                        controller: _slabNoCtrl,
                        colors: colors,
                        isRequired: true,
                        isReadOnly: true,
                        helperText: 'Auto-generated sequential slab number (Locked)',
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),

                      // Multiple Slabs Checkbox (Batch Generation)
                      if (widget.initialSlab == null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isMultipleSlabs
                                ? colors.primary.withValues(alpha: 0.1)
                                : (isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isMultipleSlabs
                                  ? colors.primary.withValues(alpha: 0.4)
                                  : colors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isMultipleSlabs = !_isMultipleSlabs;
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _isMultipleSlabs,
                                      activeColor: colors.primary,
                                      checkColor: isDark ? const Color(0xFF111418) : Colors.white,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (val) {
                                        setState(() {
                                          _isMultipleSlabs = val ?? false;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Multiple Slabs (Batch Creation)',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isMultipleSlabs) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Quantity:',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      SizedBox(
                                        width: 120,
                                        height: 38,
                                        child: TextField(
                                          controller: _quantityCtrl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          textInputAction: TextInputAction.done,
                                          onSubmitted: (_) => _saveSlab(),
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            filled: true,
                                            fillColor: colors.surface,
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              borderSide: BorderSide(color: colors.border),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              borderSide: BorderSide(color: colors.border),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              borderSide: BorderSide(color: colors.primary),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Slabs will be sequentially numbered with unique QR codes generated automatically.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: colors.textDisabled,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else
                        const SizedBox(height: 16),

                      // 3. Length_cm* (With Stepper Buttons - / +)
                      _buildStepperField(
                        label: 'Length_cm*',
                        controller: _lengthCmCtrl,
                        colors: colors,
                        step: 1.0,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),

                      // 4. Width_cm* (With Stepper Buttons - / +)
                      _buildStepperField(
                        label: 'Width_cm*',
                        controller: _widthCmCtrl,
                        colors: colors,
                        step: 1.0,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),

                      // 5. Thickness_mm* (With Stepper Buttons - / +)
                      _buildStepperField(
                        label: 'Thickness_mm*',
                        controller: _thicknessMmCtrl,
                        colors: colors,
                        step: 1.0,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),

                      // 6. Area_sqm* (Auto-Calculated Read-Only Formula)
                      _buildStandardField(
                        label: 'Area_sqm*',
                        controller: _areaSqmCtrl,
                        colors: colors,
                        isReadOnly: true,
                        helperText: 'Formula: (Length_cm * Width_cm) / 10,000',
                      ),
                      const SizedBox(height: 16),

                      // 7. RackCode (Warehouse Location Dropdown)
                      _buildFieldLabel('RackCode', isRequired: false),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRackCode,
                            dropdownColor: colors.surface,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            items: _rackOptions.map((rack) {
                              return DropdownMenuItem<String>(
                                value: rack,
                                child: Text(
                                  rack.isEmpty ? '(Unassigned)' : rack,
                                  style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                                ),
                              );
                            }).toList(),
                            onChanged: (newRack) {
                              if (newRack != null) {
                                setState(() => _selectedRackCode = newRack);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 8. Photo (Camera Upload with Preview)
                      _buildPhotoField(colors),
                      const SizedBox(height: 16),

                      // 9. ReceivedDate* (Interactive DatePicker MM/DD/YYYY)
                      _buildFieldLabel('ReceivedDate*', isRequired: true),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _selectReceivedDate,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MM/dd/yyyy').format(_receivedDate),
                                style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                              ),
                              Icon(Icons.calendar_today_outlined, size: 18, color: colors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 10. Notes (Defects / Inspection Notes)
                      _buildStandardField(
                        label: 'Notes',
                        controller: _notesCtrl,
                        colors: colors,
                      ),
                      const SizedBox(height: 16),

                      // 11. QRCodeImage (Live Scannable Unique QR Code Preview matching Screenshot 2)
                      _buildFieldLabel('QRCodeImage', isReadOnly: true),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131417) : colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: _qrPayload,
                                  version: QrVersions.auto,
                                  size: 140,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'InventoryID',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _inventoryId,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),


                      // 13. PrintLabelText (Read-Only Formula Field)
                      _buildStandardField(
                        label: 'PrintLabelText',
                        controller: _printLabelTextCtrl,
                        colors: colors,
                        isReadOnly: true,
                        helperText: 'Formula: [SlabNo] · [StoneType] / [MaterialName] · [Finish]',
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Bottom Save Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: dialogBtnTextColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: _saveSlab,
                child: Text(
                  _isMultipleSlabs && widget.initialSlab == null
                      ? 'Save ${_quantityCtrl.text.trim()} Slabs to Inventory (Batch)'
                      : (widget.initialSlab != null ? 'Update Slab' : 'Save Slab to Inventory'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label, {bool isRequired = false, bool isReadOnly = false}) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            text: label.endsWith('*') ? label.substring(0, label.length - 1) : label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isReadOnly ? colors.textDisabled : colors.textSecondary,
            ),
            children: (label.endsWith('*') || isRequired)
                ? [
                    TextSpan(
                      text: '*',
                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                    )
                  ]
                : [],
          ),
        ),
        if (isReadOnly)
          Text(
            'Read-Only',
            style: GoogleFonts.inter(fontSize: 10, color: colors.textDisabled),
          ),
      ],
    );
  }

  Widget _buildStandardField({
    required String label,
    required TextEditingController controller,
    required AppColorsExtension colors,
    bool isReadOnly = false,
    bool isRequired = false,
    String? helperText,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired: isRequired, isReadOnly: isReadOnly),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isReadOnly
                ? colors.surfaceVariant.withValues(alpha: 0.35)
                : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isReadOnly
                  ? colors.border.withValues(alpha: 0.5)
                  : colors.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            readOnly: isReadOnly,
            enabled: !isReadOnly ? true : null,
            enableInteractiveSelection: !isReadOnly,
            canRequestFocus: !isReadOnly,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: GoogleFonts.inter(
              color: isReadOnly ? colors.textSecondary : colors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              suffixIcon: isReadOnly
                  ? Icon(Icons.lock_outline_rounded, size: 16, color: colors.textDisabled)
                  : null,
            ),
          ),
        ),
        if (helperText != null && isReadOnly) ...[
          const SizedBox(height: 3),
          Text(helperText, style: GoogleFonts.inter(fontSize: 10, color: colors.textDisabled)),
        ],
      ],
    );
  }

  Widget _buildStepperField({
    required String label,
    required TextEditingController controller,
    required AppColorsExtension colors,
    required double step,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired: isRequired),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.remove, size: 18, color: colors.textSecondary),
                onPressed: () => _stepField(controller, -step),
                tooltip: 'Decrease',
              ),
              IconButton(
                icon: Icon(Icons.add, size: 18, color: colors.textSecondary),
                onPressed: () => _stepField(controller, step),
                tooltip: 'Increase',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoField(AppColorsExtension colors) {
    final hasPhoto = _photoBytes != null || (_photoUrl != null && _photoUrl!.isNotEmpty);
    final isAutoLinked = (hasPhoto &&
        ((_photoBytes != null && _photoBytes == _selectedMaterial.imageBytes) ||
         (_photoUrl != null && _photoUrl == _selectedMaterial.imageUrl)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel('Photo', isRequired: false),
            if (isAutoLinked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 11, color: colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Default from Material',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: colors.primary),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            height: 72,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasPhoto ? colors.primary : colors.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: hasPhoto
                ? Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: StoneImageWidget(
                          imageUrl: _photoUrl,
                          imageBytes: _photoBytes,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          enablePreviewOnTap: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _photoName ?? '${_selectedMaterial.name} Photo',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isAutoLinked
                                  ? 'Auto-linked from ${_selectedMaterial.materialCode} (${_selectedMaterial.name})'
                                  : 'Custom uploaded photo',
                              style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 20, color: colors.primary),
                        onPressed: _pickPhoto,
                        tooltip: 'Change Photo',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                        onPressed: _removePhoto,
                        tooltip: 'Remove Photo',
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: colors.textSecondary.withValues(alpha: 0.8),
                      size: 28,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
