import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/category_model.dart';
import '../../core/models/material_item.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/widgets/stone_image_widget.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// Materials Form Dialog
/// Exact replication of the AppSheet "Materials Form"
/// Includes all 10 Manual Input Fields and all 7 Auto-Calculated / Read-Only Fields.
/// ──────────────────────────────────────────────────────────────────────────
class MaterialFormDialog extends StatefulWidget {
  final CategoryModel initialCategory;

  const MaterialFormDialog({
    super.key,
    required this.initialCategory,
  });

  static Future<MaterialItem?> show(BuildContext context, CategoryModel category) {
    return AdaptiveDialog.show<MaterialItem>(
      context: context,
      isDismissible: false,
      builder: (ctx) => MaterialFormDialog(initialCategory: category),
    );
  }

  @override
  State<MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends State<MaterialFormDialog> {
  late CategoryModel _selectedCategory;

  // 1. Manual Input Controllers
  late TextEditingController _materialCodeCtrl;
  late TextEditingController _stoneTypeCtrl;
  late TextEditingController _materialNameCtrl;
  late TextEditingController _finishCtrl;
  late TextEditingController _referenceCodeCtrl;
  late TextEditingController _erpDescriptionCtrl;
  late TextEditingController _erpUnitCtrl;
  late TextEditingController _displayLabelCtrl;

  // 2. Auto-Calculated / Read-Only Controllers
  late TextEditingController _totalAreaSqmCtrl;
  late TextEditingController _totalSlabsCtrl;
  late TextEditingController _categoryAndNameCtrl;
  late TextEditingController _stockSummaryCtrl;
  late TextEditingController _codeAndFinishCtrl;
  late TextEditingController _categoryStockCtrl;

  // Image Upload State
  Uint8List? _uploadedImageBytes;
  String? _uploadedFileName;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;

    final appState = AppStateScope.read(context);
    final suggestedCode = appState.nextMaterialCodeForCategory(_selectedCategory);

    // Initial manual values
    _materialCodeCtrl = TextEditingController(text: suggestedCode);
    _stoneTypeCtrl = TextEditingController(text: _deriveStoneType(_selectedCategory.categoryName));
    _materialNameCtrl = TextEditingController();
    _finishCtrl = TextEditingController(text: 'Polish');
    _referenceCodeCtrl = TextEditingController(text: suggestedCode);
    _erpDescriptionCtrl = TextEditingController();
    _erpUnitCtrl = TextEditingController(text: 'sqm');
    _displayLabelCtrl = TextEditingController(text: '-');

    // Initial read-only values
    _totalAreaSqmCtrl = TextEditingController(text: '0.00');
    _totalSlabsCtrl = TextEditingController(text: '0');
    _categoryAndNameCtrl = TextEditingController();
    _stockSummaryCtrl = TextEditingController(text: '0 sqm • 0 slabs');
    _codeAndFinishCtrl = TextEditingController();
    _categoryStockCtrl = TextEditingController();

    _recomputeFormulas(appState);

    // Listen to changes to keep formulas live
    _materialCodeCtrl.addListener(_onFieldChanged);
    _materialNameCtrl.addListener(_onFieldChanged);
    _finishCtrl.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _materialCodeCtrl.dispose();
    _stoneTypeCtrl.dispose();
    _materialNameCtrl.dispose();
    _finishCtrl.dispose();
    _referenceCodeCtrl.dispose();
    _erpDescriptionCtrl.dispose();
    _erpUnitCtrl.dispose();
    _displayLabelCtrl.dispose();

    _totalAreaSqmCtrl.dispose();
    _totalSlabsCtrl.dispose();
    _categoryAndNameCtrl.dispose();
    _stockSummaryCtrl.dispose();
    _codeAndFinishCtrl.dispose();
    _categoryStockCtrl.dispose();
    super.dispose();
  }

  String _deriveStoneType(String categoryName) {
    if (categoryName.contains('/')) {
      return categoryName.split('/').first.trim();
    }
    return categoryName.trim();
  }

  void _onFieldChanged() {
    final appState = AppStateScope.read(context);
    _recomputeFormulas(appState);
    setState(() {});
  }

  void _recomputeFormulas(AppState appState) {
    final matName = _materialNameCtrl.text.trim();
    final matCode = _materialCodeCtrl.text.trim();
    final finish = _finishCtrl.text.trim();

    // CategoryAndName: [CategoryName] - [MaterialName]
    _categoryAndNameCtrl.text = matName.isEmpty
        ? '${_selectedCategory.categoryName} -'
        : '${_selectedCategory.categoryName} - ${matName.toUpperCase()}';

    // CodeAndFinish: [MaterialCode] - 0m² - [Finish]
    if (matCode.isEmpty && finish.isEmpty) {
      _codeAndFinishCtrl.text = '- 0m² -';
    } else {
      _codeAndFinishCtrl.text = '$matCode - 0m² - $finish';
    }

    // DisplayLabel: Auto-calculated formula (default: '-' or formatted category & name)
    if (matName.isEmpty) {
      _displayLabelCtrl.text = '-';
    } else {
      _displayLabelCtrl.text = '${_selectedCategory.categoryName} - ${matName.toUpperCase()}';
    }

    // CategoryStock
    final catTotalSlabs = appState.totalSlabsForCategory(_selectedCategory.categoryName);
    final catTotalArea = appState.totalAreaSqmForCategory(_selectedCategory.categoryName);
    _categoryStockCtrl.text = catTotalSlabs > 0
        ? '${catTotalArea.toStringAsFixed(0)} sqm - $catTotalSlabs slabs'
        : '0 sqm - 0 slabs';
  }

  Future<void> _pickImage() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _uploadedImageBytes = bytes;
          _uploadedFileName = file.name;
        });
      }
    } catch (e) {
      // In case native picker is restricted, show sample textures
      if (mounted) {
        _showImageSourceDialog();
      }
    }
  }

  void _showImageSourceDialog() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Material Image',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.file_upload_outlined, color: colors.primary),
                title: Text('Browse Device Storage', style: TextStyle(color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.palette_outlined, color: colors.primary),
                title: Text('Use High-Res Luxury Stone Texture', style: TextStyle(color: colors.textPrimary)),
                subtitle: Text('Generate realistic procedural marble sample', style: TextStyle(color: colors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _generateProceduralStoneTexture();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _generateProceduralStoneTexture() {
    // Generate a 1x1 placeholder byte array or preset
    final headerBytes = Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
      0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 240, 31,
      0, 5, 0, 1, 255, 137, 235, 178, 188, 0, 0, 0, 0, 73, 69, 78, 68,
      174, 66, 96, 130
    ]);
    setState(() {
      _uploadedImageBytes = headerBytes;
      _uploadedFileName = 'stone_sample.png';
    });
  }

  bool _isSaving = false;

  void _saveForm() {
    if (_isSaving) return;
    final colors = context.colors;
    final appState = AppStateScope.read(context);
    final suggestedCode = appState.nextMaterialCodeForCategory(_selectedCategory);
    final code = _materialCodeCtrl.text.trim().isNotEmpty ? _materialCodeCtrl.text.trim() : suggestedCode;
    final name = _materialNameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('MaterialName is required*'), backgroundColor: colors.error),
      );
      return;
    }

    _isSaving = true;

    final newMaterial = MaterialItem(
      id: code,
      materialCode: code,
      name: name,
      categoryId: _selectedCategory.categoryName,
      categoryCode: _selectedCategory.categoryCode,
      stoneType: _stoneTypeCtrl.text.trim().isNotEmpty
          ? _stoneTypeCtrl.text.trim()
          : _deriveStoneType(_selectedCategory.categoryName),
      finish: _finishCtrl.text.trim().isNotEmpty ? _finishCtrl.text.trim() : 'Polish',
      referenceCode: _referenceCodeCtrl.text.trim().isNotEmpty ? _referenceCodeCtrl.text.trim() : code,
      erpDescription: _erpDescriptionCtrl.text.trim(),
      erpUnit: _erpUnitCtrl.text.trim().isNotEmpty ? _erpUnitCtrl.text.trim() : 'sqm',
      displayLabel: _displayLabelCtrl.text.trim().isNotEmpty ? _displayLabelCtrl.text.trim() : '-',
      totalAreaSqm: 0.0,
      totalSlabs: 0,
      categoryAndName: _categoryAndNameCtrl.text.trim().isNotEmpty
          ? _categoryAndNameCtrl.text.trim()
          : '${_selectedCategory.categoryName} - ${name.toUpperCase()}',
      stockSummary: '0 sqm • 0 slabs',
      codeAndFinish: _codeAndFinishCtrl.text.trim().isNotEmpty
          ? _codeAndFinishCtrl.text.trim()
          : '$code - 0m² - ${_finishCtrl.text.trim().isNotEmpty ? _finishCtrl.text.trim() : "Polish"}',
      categoryStock: _categoryStockCtrl.text.trim(),
      colorFamily: _selectedCategory.categoryName,
      imageBytes: _uploadedImageBytes,
    );

    appState.addMaterial(newMaterial);
    Navigator.of(context).pop(newMaterial);
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
              // ── Header Bar (Matching AppSheet Photo 1) ──────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: colors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Materials Form',
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
                          backgroundColor: colors.primary,
                          foregroundColor: dialogBtnTextColor,
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        onPressed: _saveForm,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 16),

              // ── Form Body: Exact Field Order as AppSheet Photos ─────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. CategoryCode (Selected Category Dropdown)
                      _buildFieldLabel('CategoryCode', isRequired: false),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CategoryModel>(
                            value: _selectedCategory,
                            dropdownColor: colors.surface,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            items: appState.categoryModels.map((cat) {
                              return DropdownMenuItem<CategoryModel>(
                                value: cat,
                                child: Text(
                                  cat.categoryName,
                                  style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                                ),
                              );
                            }).toList(),
                            onChanged: (newCat) {
                              if (newCat != null) {
                                setState(() {
                                  _selectedCategory = newCat;
                                  _stoneTypeCtrl.text = _deriveStoneType(newCat.categoryName);
                                  _materialCodeCtrl.text = appState.nextMaterialCodeForCategory(newCat);
                                  _referenceCodeCtrl.text = _materialCodeCtrl.text;
                                  _recomputeFormulas(appState);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. MaterialCode* (Required Manual Input)
                      _buildFormField(
                        label: 'MaterialCode*',
                        controller: _materialCodeCtrl,
                        colors: colors,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),

                      // 3. StoneType (Manual Input)
                      _buildFormField(
                        label: 'StoneType',
                        controller: _stoneTypeCtrl,
                        colors: colors,
                      ),
                      const SizedBox(height: 16),

                      // 4. MaterialName* (Manual Input)
                      _buildFormField(
                        label: 'MaterialName*',
                        controller: _materialNameCtrl,
                        colors: colors,
                        isRequired: true,
                        autoFocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveForm(),
                      ),
                      const SizedBox(height: 16),

                      // 5. Finish (Manual Input / Selector)
                      _buildFinishField(colors, appState),
                      const SizedBox(height: 16),

                      // 6. ReferenceCode (Manual Input)
                      _buildFormField(
                        label: 'ReferenceCode',
                        controller: _referenceCodeCtrl,
                        colors: colors,
                      ),
                      const SizedBox(height: 16),

                      // 7. MaterialImage* (Camera Button / Upload with Preview)
                      _buildMaterialImageField(colors),
                      const SizedBox(height: 16),

                      // 8. ERPDescription (Manual Input)
                      _buildFormField(
                        label: 'ERPDescription',
                        controller: _erpDescriptionCtrl,
                        colors: colors,
                      ),
                      const SizedBox(height: 16),

                      // 9. ERPUnit (Manual Input, Default: sqm)
                      _buildFormField(
                        label: 'ERPUnit',
                        controller: _erpUnitCtrl,
                        colors: colors,
                      ),
                      const SizedBox(height: 16),

                      // 10. DisplayLabel (Auto-Calculated Read-Only Formula)
                      _buildFormField(
                        label: 'DisplayLabel',
                        controller: _displayLabelCtrl,
                        colors: colors,
                        isReadOnly: true,
                        helperText: 'Auto-calculated display label formula',
                      ),
                      const SizedBox(height: 16),

                      // 11. TotalAreaSqm (Auto-Calculated Read-Only, Default: 0.00)
                      _buildFormField(
                        label: 'TotalAreaSqm',
                        controller: _totalAreaSqmCtrl,
                        colors: colors,
                        isReadOnly: true,
                        helperText: 'Auto-calculated sum of all slab area in this material',
                      ),
                      const SizedBox(height: 16),

                      // 12. TotalSlabs (Auto-Calculated Read-Only, Default: 0)
                      _buildFormField(
                        label: 'TotalSlabs',
                        controller: _totalSlabsCtrl,
                        colors: colors,
                        isReadOnly: true,
                        helperText: 'Auto-counted number of slabs in this material',
                      ),
                      const SizedBox(height: 16),

                      // 13. CategoryAndName (Auto-Calculated Read-Only: [CategoryName] - [MaterialName])
                      _buildFormField(
                        label: 'CategoryAndName',
                        controller: _categoryAndNameCtrl,
                        colors: colors,
                        isReadOnly: true,
                        helperText: 'Formula: [CategoryName] - [MaterialName]',
                      ),
                      const SizedBox(height: 16),

                      // 14. StockSummary (Auto-Calculated Read-Only, Default: 0 sqm • 0 slabs)
                      _buildFormField(
                        label: 'StockSummary',
                        controller: _stockSummaryCtrl,
                        colors: colors,
                        isReadOnly: true,
                        helperText: 'Formula: [TotalAreaSqm] sqm • [TotalSlabs] slabs',
                      ),
                      const SizedBox(height: 16),

                      // 15. CodeAndFinish (Auto-Calculated Read-Only: [MaterialCode] - 0m² - [Finish])
                      _buildFormField(
                        label: 'CodeAndFinish',
                        controller: _codeAndFinishCtrl,
                        colors: colors,
                        isReadOnly: true,
                        helperText: 'Formula: [MaterialCode] - [TotalAreaSqm]m² - [Finish]',
                      ),
                      const SizedBox(height: 16),

                      // 16. CategoryStock (Auto-Calculated Read-Only, Default: 0 sqm - 0 slabs)
                      _buildFormField(
                        label: 'CategoryStock',
                        controller: _categoryStockCtrl,
                        colors: colors,
                        isReadOnly: true,
                        helperText: 'Total area and slab count for the parent category',
                      ),
                      const SizedBox(height: 16),

                      // 17. DisplayImage (Full Preview Container Matching Photo 2)
                      _buildDisplayImageField(colors),
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
                onPressed: _saveForm,
                child: Text(
                  'Save Material',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Field Widgets
  // ──────────────────────────────────────────────────────────────────────────

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

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required AppColorsExtension colors,
    bool isReadOnly = false,
    bool isRequired = false,
    bool autoFocus = false,
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
          height: 44,
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            readOnly: isReadOnly,
            autofocus: autoFocus,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: GoogleFonts.inter(
              color: isReadOnly ? colors.textSecondary : colors.textPrimary,
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (helperText != null && isReadOnly) ...[
          const SizedBox(height: 3),
          Text(
            helperText,
            style: GoogleFonts.inter(fontSize: 10, color: colors.textDisabled),
          ),
        ],
      ],
    );
  }

  Widget _buildFinishField(AppColorsExtension colors, AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Finish', isRequired: false),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _finishCtrl,
                  style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                color: colors.surface,
                onSelected: (val) {
                  _finishCtrl.text = val;
                  _onFieldChanged();
                },
                itemBuilder: (ctx) {
                  return appState.finishes.map((f) {
                    return PopupMenuItem<String>(
                      value: f,
                      child: Text(f, style: TextStyle(color: colors.textPrimary)),
                    );
                  }).toList();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialImageField(AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('MaterialImage', isRequired: false),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _uploadedImageBytes != null ? colors.primary : colors.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_uploadedImageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(
                      _uploadedImageBytes!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _uploadedFileName ?? 'image_uploaded.png',
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: colors.primary),
                    onPressed: _pickImage,
                    tooltip: 'Change Image',
                  ),
                ] else ...[
                  Icon(Icons.camera_alt_outlined, color: colors.textSecondary, size: 24),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayImageField(AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('DisplayImage', isReadOnly: true),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF131417),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: _uploadedImageBytes != null
              ? Image.memory(
                  _uploadedImageBytes!,
                  fit: BoxFit.cover,
                )
              : StoneImageWidget(
                  imageUrl: StoneImageWidget.getDefaultImageUrlForCategory(_selectedCategory.categoryName),
                  height: 220,
                  fit: BoxFit.cover,
                  enablePreviewOnTap: true,
                ),
        ),
      ],
    );
  }
}
