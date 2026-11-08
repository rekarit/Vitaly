import '../models/category.dart';
import '../models/material_item.dart';
import '../models/slab.dart';
import '../models/customer.dart';
import '../models/reservation.dart';
import '../models/sale.dart';

/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// VITALY APP â€” Realistic In-Memory Mock Data
/// Stone catalog modelled after real warehouse inventory.
/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class MockData {
  MockData._(); // pure static â€” no instances


  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ CATEGORIES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const List<Category> categories = [
    Category(id: 'cat_01', name: 'Marble',     description: 'Natural crystalline limestone', slabCount: 48),
    Category(id: 'cat_02', name: 'Granite',    description: 'Igneous plutonic rock',         slabCount: 31),
    Category(id: 'cat_03', name: 'Quartzite',  description: 'Metamorphic silica-rich stone', slabCount: 19),
    Category(id: 'cat_04', name: 'Travertine', description: 'Sedimentary limestone deposit', slabCount: 12),
    Category(id: 'cat_05', name: 'Onyx',       description: 'Translucent banded calcite',   slabCount: 7),
    Category(id: 'cat_06', name: 'Wood',       description: 'Premium hardwood panels',       slabCount: 22),
  ];

  // ─────────────────── FIXED MASTER MATERIALS (AppSheet Aligned) ─────────────
  static final List<MaterialItem> masterMaterials = [
    // 12. Quartzite / Crystal
    MaterialItem(
      id: '1201',
      materialCode: '1201',
      name: 'CALACATTA GOLD',
      categoryId: 'Quartzite / Crystal',
      categoryCode: 12,
      stoneType: 'Quartzite',
      finish: 'Polish',
      origin: 'Italy',
      pricePerSqm: 285.0,
      imageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=800&q=80',
    ),
    MaterialItem(
      id: '1202',
      materialCode: '1202',
      name: 'CRISTALLO TIFFANY',
      categoryId: 'Quartzite / Crystal',
      categoryCode: 12,
      stoneType: 'Quartzite',
      finish: 'Polish',
      origin: 'Brazil',
      pricePerSqm: 320.0,
      imageUrl: 'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=800&q=80',
    ),
    MaterialItem(
      id: '1203',
      materialCode: '1203',
      name: 'TAJ MAHAL',
      categoryId: 'Quartzite / Crystal',
      categoryCode: 12,
      stoneType: 'Quartzite',
      finish: 'Leather',
      origin: 'Brazil',
      pricePerSqm: 240.0,
      imageUrl: 'https://images.unsplash.com/photo-1541123437800-1bb1317badc2?auto=format&fit=crop&w=800&q=80',
    ),
    // 13. Marble
    MaterialItem(
      id: '1301',
      materialCode: '1301',
      name: 'STATUARIO VENATO',
      categoryId: 'Marble',
      categoryCode: 13,
      stoneType: 'Marble',
      finish: 'Polish',
      origin: 'Italy',
      pricePerSqm: 310.0,
      imageUrl: 'https://images.unsplash.com/photo-1590381105924-c72589b9ef3f?auto=format&fit=crop&w=800&q=80',
    ),
    MaterialItem(
      id: '1302',
      materialCode: '1302',
      name: 'BIANCO CALACATTA',
      categoryId: 'Marble',
      categoryCode: 13,
      stoneType: 'Marble',
      finish: 'Polish',
      origin: 'Italy',
      pricePerSqm: 195.0,
      imageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=800&q=80',
    ),
    MaterialItem(
      id: '1303',
      materialCode: '1303',
      name: 'NERO MARQUINA',
      categoryId: 'Marble',
      categoryCode: 13,
      stoneType: 'Marble',
      finish: 'Polish',
      origin: 'Spain',
      pricePerSqm: 175.0,
      imageUrl: 'https://images.unsplash.com/photo-1588854337236-6889d631faa8?auto=format&fit=crop&w=800&q=80',
    ),
    // 14. Granite
    MaterialItem(
      id: '1401',
      materialCode: '1401',
      name: 'BLACK GALAXY',
      categoryId: 'Granite',
      categoryCode: 14,
      stoneType: 'Granite',
      finish: 'Polish',
      origin: 'India',
      pricePerSqm: 110.0,
      imageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=800&q=80',
    ),
    MaterialItem(
      id: '1402',
      materialCode: '1402',
      name: 'BLUE PEARL',
      categoryId: 'Granite',
      categoryCode: 14,
      stoneType: 'Granite',
      finish: 'Polish',
      origin: 'Norway',
      pricePerSqm: 145.0,
      imageUrl: 'https://images.unsplash.com/photo-1507499739999-097706ad8914?auto=format&fit=crop&w=800&q=80',
    ),
    // 15. Onyx
    MaterialItem(
      id: '1501',
      materialCode: '1501',
      name: 'GREEN ONYX',
      categoryId: 'Onyx',
      categoryCode: 15,
      stoneType: 'Onyx',
      finish: 'Polish',
      origin: 'Pakistan',
      pricePerSqm: 380.0,
      imageUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=800&q=80',
    ),
    MaterialItem(
      id: '1502',
      materialCode: '1502',
      name: 'HONEY ONYX',
      categoryId: 'Onyx',
      categoryCode: 15,
      stoneType: 'Onyx',
      finish: 'Polish',
      origin: 'Iran',
      pricePerSqm: 320.0,
      imageUrl: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?auto=format&fit=crop&w=800&q=80',
    ),
    // 16. Travertine
    MaterialItem(
      id: '1601',
      materialCode: '1601',
      name: 'CLASSIC TRAVERTINE',
      categoryId: 'Travertine',
      categoryCode: 16,
      stoneType: 'Travertine',
      finish: 'Honed',
      origin: 'Turkey',
      pricePerSqm: 55.0,
      imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=800&q=80',
    ),
    MaterialItem(
      id: '1602',
      materialCode: '1602',
      name: 'SILVER TRAVERTINE',
      categoryId: 'Travertine',
      categoryCode: 16,
      stoneType: 'Travertine',
      finish: 'Brushed',
      origin: 'Iran',
      pricePerSqm: 70.0,
      imageUrl: 'https://images.unsplash.com/photo-1598880940371-c756e015fea1?auto=format&fit=crop&w=800&q=80',
    ),
    // 17. Crystal / Semi Precious
    MaterialItem(
      id: '1701',
      materialCode: '1701',
      name: 'BLUE AGATE',
      categoryId: 'Crystal / Semi Precious',
      categoryCode: 17,
      stoneType: 'Crystal',
      finish: 'Polish',
      origin: 'Madagascar',
      pricePerSqm: 550.0,
      imageUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=800&q=80',
    ),
    MaterialItem(
      id: '1702',
      materialCode: '1702',
      name: 'AMETHYST CRYSTAL',
      categoryId: 'Crystal / Semi Precious',
      categoryCode: 17,
      stoneType: 'Crystal',
      finish: 'Polish',
      origin: 'Brazil',
      pricePerSqm: 620.0,
      imageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=800&q=80',
    ),
  ];

  static final List<MaterialItem> materials = [
    // Marble
    MaterialItem(id: 'mat_01', name: 'Calacatta Gold',       categoryId: 'cat_01', origin: 'Italy',    finish: 'Polished',  pricePerSqm: 285.0, colorFamily: 'White'),
    MaterialItem(id: 'mat_02', name: 'Bianco Calacatta',     categoryId: 'cat_01', origin: 'Italy',    finish: 'Polished',  pricePerSqm: 195.0, colorFamily: 'White'),
    MaterialItem(id: 'mat_03', name: 'Silk Emperador',       categoryId: 'cat_01', origin: 'Spain',    finish: 'Polished',  pricePerSqm: 160.0, colorFamily: 'Brown'),
    MaterialItem(id: 'mat_04', name: 'Nero Marquina',        categoryId: 'cat_01', origin: 'Spain',    finish: 'Polished',  pricePerSqm: 175.0, colorFamily: 'Black'),
    MaterialItem(id: 'mat_05', name: 'Scato White',          categoryId: 'cat_01', origin: 'Turkey',   finish: 'Honed',     pricePerSqm: 95.0,  colorFamily: 'White'),
    MaterialItem(id: 'mat_06', name: 'Arabescato Corchia',   categoryId: 'cat_01', origin: 'Italy',    finish: 'Polished',  pricePerSqm: 220.0, colorFamily: 'White'),
    MaterialItem(id: 'mat_07', name: 'Statuario Venato',     categoryId: 'cat_01', origin: 'Italy',    finish: 'Polished',  pricePerSqm: 310.0, colorFamily: 'White'),
    MaterialItem(id: 'mat_08', name: 'Crema Marfil',         categoryId: 'cat_01', origin: 'Spain',    finish: 'Polished',  pricePerSqm: 85.0,  colorFamily: 'Beige'),
    // Granite
    MaterialItem(id: 'mat_09', name: 'Black Galaxy',         categoryId: 'cat_02', origin: 'India',    finish: 'Polished',  pricePerSqm: 110.0, colorFamily: 'Black'),
    MaterialItem(id: 'mat_10', name: 'Absolute Black',       categoryId: 'cat_02', origin: 'India',    finish: 'Leathered', pricePerSqm: 90.0,  colorFamily: 'Black'),
    MaterialItem(id: 'mat_11', name: 'River White',          categoryId: 'cat_02', origin: 'India',    finish: 'Polished',  pricePerSqm: 80.0,  colorFamily: 'White'),
    MaterialItem(id: 'mat_12', name: 'Blue Pearl',           categoryId: 'cat_02', origin: 'Norway',   finish: 'Polished',  pricePerSqm: 145.0, colorFamily: 'Grey'),
    // Quartzite
    MaterialItem(id: 'mat_13', name: 'Sea Pearl',            categoryId: 'cat_03', origin: 'Brazil',   finish: 'Honed',     pricePerSqm: 200.0, colorFamily: 'White'),
    MaterialItem(id: 'mat_14', name: 'Fantasy Brown',        categoryId: 'cat_03', origin: 'India',    finish: 'Polished',  pricePerSqm: 130.0, colorFamily: 'Beige'),
    // Travertine
    MaterialItem(id: 'mat_15', name: 'Classic Travertine',   categoryId: 'cat_04', origin: 'Turkey',   finish: 'Honed',     pricePerSqm: 55.0,  colorFamily: 'Beige'),
    MaterialItem(id: 'mat_16', name: 'Silver Travertine',    categoryId: 'cat_04', origin: 'Iran',     finish: 'Brushed',   pricePerSqm: 70.0,  colorFamily: 'Grey'),
    // Onyx
    MaterialItem(id: 'mat_17', name: 'Green Onyx',           categoryId: 'cat_05', origin: 'Pakistan', finish: 'Polished',  pricePerSqm: 380.0, colorFamily: 'White'),
    MaterialItem(id: 'mat_18', name: 'Honey Onyx',           categoryId: 'cat_05', origin: 'Iran',     finish: 'Polished',  pricePerSqm: 320.0, colorFamily: 'Gold'),
    // Wood
    MaterialItem(id: 'mat_19', name: 'White Oak Engineered', categoryId: 'cat_06', origin: 'USA',      finish: 'Brushed',   pricePerSqm: 75.0,  colorFamily: 'Beige'),
    MaterialItem(id: 'mat_20', name: 'Smoked Walnut',        categoryId: 'cat_06', origin: 'France',   finish: 'Leathered', pricePerSqm: 120.0, colorFamily: 'Brown'),
  ];

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ SLABS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Slab> slabs = [
    // â”€â”€ Calacatta Gold â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_001', materialId: 'mat_01', bundleNumber: 'BND-CG-001', slabNumber: 1,
        lengthCm: 320.0, widthCm: 180.0, thicknessCm: 2.0, areaSqm: 5.76, netAreaSqm: 5.76,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block A - Row 1',
        receivedDate: DateTime(2025, 3, 10)),
    Slab(id: 's_002', materialId: 'mat_01', bundleNumber: 'BND-CG-001', slabNumber: 2,
        lengthCm: 318.0, widthCm: 175.0, thicknessCm: 2.0, areaSqm: 5.565, netAreaSqm: 5.20,
        status: SlabStatus.available, hasDefect: true,
        defectNotes: 'Small hairline crack on upper left corner, 8cm length',
        warehouseLocation: 'Block A - Row 1', receivedDate: DateTime(2025, 3, 10)),
    Slab(id: 's_003', materialId: 'mat_01', bundleNumber: 'BND-CG-001', slabNumber: 3,
        lengthCm: 322.0, widthCm: 182.0, thicknessCm: 2.0, areaSqm: 5.860, netAreaSqm: 5.860,
        status: SlabStatus.reserved, hasDefect: false, warehouseLocation: 'Block A - Row 1',
        receivedDate: DateTime(2025, 3, 10), reservedPrice: 290.0),
    Slab(id: 's_004', materialId: 'mat_01', bundleNumber: 'BND-CG-002', slabNumber: 1,
        lengthCm: 315.0, widthCm: 178.0, thicknessCm: 3.0, areaSqm: 5.607, netAreaSqm: 5.607,
        status: SlabStatus.sold, hasDefect: false, warehouseLocation: 'Block A - Row 2',
        receivedDate: DateTime(2025, 1, 22)),

    // â”€â”€ Bianco Calacatta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_005', materialId: 'mat_02', bundleNumber: 'BND-BC-001', slabNumber: 1,
        lengthCm: 300.0, widthCm: 170.0, thicknessCm: 2.0, areaSqm: 5.10, netAreaSqm: 5.10,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block A - Row 3',
        receivedDate: DateTime(2025, 4, 5)),
    Slab(id: 's_006', materialId: 'mat_02', bundleNumber: 'BND-BC-001', slabNumber: 2,
        lengthCm: 298.0, widthCm: 168.0, thicknessCm: 2.0, areaSqm: 5.006, netAreaSqm: 4.80,
        status: SlabStatus.available, hasDefect: true,
        defectNotes: 'Surface scratch on lower middle â€” repolishable',
        warehouseLocation: 'Block A - Row 3', receivedDate: DateTime(2025, 4, 5)),
    Slab(id: 's_007', materialId: 'mat_02', bundleNumber: 'BND-BC-002', slabNumber: 1,
        lengthCm: 310.0, widthCm: 172.0, thicknessCm: 3.0, areaSqm: 5.332, netAreaSqm: 5.332,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block B - Row 1',
        receivedDate: DateTime(2025, 4, 5)),

    // â”€â”€ Silk Emperador â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_008', materialId: 'mat_03', bundleNumber: 'BND-SE-001', slabNumber: 1,
        lengthCm: 280.0, widthCm: 155.0, thicknessCm: 2.0, areaSqm: 4.340, netAreaSqm: 4.340,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block B - Row 2',
        receivedDate: DateTime(2025, 2, 18)),
    Slab(id: 's_009', materialId: 'mat_03', bundleNumber: 'BND-SE-001', slabNumber: 2,
        lengthCm: 275.0, widthCm: 152.0, thicknessCm: 2.0, areaSqm: 4.18, netAreaSqm: 4.18,
        status: SlabStatus.reserved, hasDefect: false, warehouseLocation: 'Block B - Row 2',
        receivedDate: DateTime(2025, 2, 18), reservedPrice: 165.0),

    // â”€â”€ Nero Marquina â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_010', materialId: 'mat_04', bundleNumber: 'BND-NM-001', slabNumber: 1,
        lengthCm: 290.0, widthCm: 160.0, thicknessCm: 2.0, areaSqm: 4.640, netAreaSqm: 4.640,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block B - Row 3',
        receivedDate: DateTime(2025, 5, 1)),
    Slab(id: 's_011', materialId: 'mat_04', bundleNumber: 'BND-NM-001', slabNumber: 2,
        lengthCm: 288.0, widthCm: 158.0, thicknessCm: 2.0, areaSqm: 4.550, netAreaSqm: 4.00,
        status: SlabStatus.available, hasDefect: true,
        defectNotes: 'Chipped edge on right side â€” 25cm segment, minor',
        warehouseLocation: 'Block B - Row 3', receivedDate: DateTime(2025, 5, 1)),

    // â”€â”€ Scato White â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_012', materialId: 'mat_05', bundleNumber: 'BND-SW-001', slabNumber: 1,
        lengthCm: 330.0, widthCm: 200.0, thicknessCm: 2.0, areaSqm: 6.60, netAreaSqm: 6.60,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block C - Row 1',
        receivedDate: DateTime(2025, 6, 12)),
    Slab(id: 's_013', materialId: 'mat_05', bundleNumber: 'BND-SW-001', slabNumber: 2,
        lengthCm: 328.0, widthCm: 198.0, thicknessCm: 2.0, areaSqm: 6.494, netAreaSqm: 6.494,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block C - Row 1',
        receivedDate: DateTime(2025, 6, 12)),

    // â”€â”€ Statuario Venato â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_014', materialId: 'mat_07', bundleNumber: 'BND-SV-001', slabNumber: 1,
        lengthCm: 305.0, widthCm: 165.0, thicknessCm: 2.0, areaSqm: 5.0325, netAreaSqm: 5.0325,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block A - Row 4',
        receivedDate: DateTime(2025, 6, 20)),

    // â”€â”€ Black Galaxy â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_015', materialId: 'mat_09', bundleNumber: 'BND-BG-001', slabNumber: 1,
        lengthCm: 295.0, widthCm: 162.0, thicknessCm: 3.0, areaSqm: 4.779, netAreaSqm: 4.779,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block D - Row 1',
        receivedDate: DateTime(2025, 3, 28)),
    Slab(id: 's_016', materialId: 'mat_09', bundleNumber: 'BND-BG-001', slabNumber: 2,
        lengthCm: 292.0, widthCm: 160.0, thicknessCm: 3.0, areaSqm: 4.672, netAreaSqm: 4.20,
        status: SlabStatus.damaged, hasDefect: true,
        defectNotes: 'Deep crack running diagonally â€” structural damage, not saleable as full slab',
        warehouseLocation: 'Block D - Row 1', receivedDate: DateTime(2025, 3, 28)),

    // â”€â”€ Sea Pearl Quartzite â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_017', materialId: 'mat_13', bundleNumber: 'BND-SP-001', slabNumber: 1,
        lengthCm: 315.0, widthCm: 170.0, thicknessCm: 2.0, areaSqm: 5.355, netAreaSqm: 5.355,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block E - Row 1',
        receivedDate: DateTime(2025, 7, 3)),

    // â”€â”€ Honey Onyx â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_018', materialId: 'mat_18', bundleNumber: 'BND-HO-001', slabNumber: 1,
        lengthCm: 220.0, widthCm: 110.0, thicknessCm: 2.0, areaSqm: 2.42, netAreaSqm: 2.42,
        status: SlabStatus.reserved, hasDefect: false, warehouseLocation: 'Block F - Row 1',
        receivedDate: DateTime(2025, 5, 15), reservedPrice: 325.0),

    // â”€â”€ White Oak Wood â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Slab(id: 's_019', materialId: 'mat_19', bundleNumber: 'BND-WO-001', slabNumber: 1,
        lengthCm: 240.0, widthCm: 20.0, thicknessCm: 1.4, areaSqm: 0.48, netAreaSqm: 0.48,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block G - Row 1',
        receivedDate: DateTime(2025, 8, 1)),
    Slab(id: 's_020', materialId: 'mat_19', bundleNumber: 'BND-WO-001', slabNumber: 2,
        lengthCm: 240.0, widthCm: 20.0, thicknessCm: 1.4, areaSqm: 0.48, netAreaSqm: 0.48,
        status: SlabStatus.available, hasDefect: false, warehouseLocation: 'Block G - Row 1',
        receivedDate: DateTime(2025, 8, 1)),
  ];

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ CUSTOMERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Customer> customers = [
    Customer(id: 'cust_01', fullName: 'Ariana Khalil',      company: 'Khalil Interiors LLC',   phone: '+971 50 234 5678', email: 'ariana@khalilinteriors.ae', city: 'Dubai',     createdAt: DateTime(2024, 9, 14)),
    Customer(id: 'cust_02', fullName: 'Marcus Steinberg',   company: 'Steinberg Architecture', phone: '+49 89 1234 5678',  email: 'm.steinberg@sa-firm.de',    city: 'Munich',    createdAt: DateTime(2024, 11, 3)),
    Customer(id: 'cust_03', fullName: 'Fatima Al-Rashid',   company: 'Al-Rashid Properties',   phone: '+966 55 876 4321', email: 'f.alrashid@arp.sa',          city: 'Riyadh',    createdAt: DateTime(2025, 1, 7)),
    Customer(id: 'cust_04', fullName: 'Luca Marini',        company: 'Marini Design Studio',   phone: '+39 02 4567 8901', email: 'luca@marinidesign.it',        city: 'Milan',     createdAt: DateTime(2025, 2, 20)),
    Customer(id: 'cust_05', fullName: 'Natalie Voss',       company: 'Voss Luxury Homes',      phone: '+1 212 555 0198',  email: 'natalie@vossluxury.com',     city: 'New York',  createdAt: DateTime(2025, 3, 11)),
    Customer(id: 'cust_06', fullName: 'Reza Tehrani',       company: 'Tehrani Construction',   phone: '+98 21 8876 5432', email: 'reza@tehranico.ir',           city: 'Tehran',    createdAt: DateTime(2025, 4, 2)),
  ];

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ RESERVATIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Reservation> reservations = [
    Reservation(
      id: 'res_001', customerId: 'cust_01',
      slabIds: ['s_003', 's_009'],
      reservedAt: DateTime(2025, 8, 1),
      expiresAt: DateTime(2025, 8, 15),
      status: ReservationStatus.active,
      depositAmount: 1200.0,
      notes: 'Kitchen island project â€” client wants matching veining',
    ),
    Reservation(
      id: 'res_002', customerId: 'cust_03',
      slabIds: ['s_018'],
      reservedAt: DateTime(2025, 7, 28),
      expiresAt: DateTime(2025, 8, 10),
      status: ReservationStatus.active,
      depositAmount: 500.0,
      notes: 'Backlit feature wall, master bathroom',
    ),
    Reservation(
      id: 'res_003', customerId: 'cust_05',
      slabIds: ['s_014'],
      reservedAt: DateTime(2025, 6, 10),
      expiresAt: DateTime(2025, 6, 25),
      status: ReservationStatus.expired,
      depositAmount: 800.0,
    ),
  ];

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ SALES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Sale> sales = [
    Sale(
      id: 'sale_001', customerId: 'cust_02',
      saleDate: DateTime(2025, 5, 20),
      status: SaleStatus.paid,
      paymentMethod: PaymentMethod.bankTransfer,
      discountPercent: 5.0,
      invoiceNumber: 'INV-2025-0042',
      lineItems: const [
        SaleLineItem(slabId: 's_004', agreedPricePerSqm: 280.0, areaSqm: 5.607),
      ],
      notes: 'Executive conference table top',
    ),
    Sale(
      id: 'sale_002', customerId: 'cust_04',
      saleDate: DateTime(2025, 7, 8),
      status: SaleStatus.invoiced,
      paymentMethod: PaymentMethod.creditCard,
      discountPercent: 0.0,
      invoiceNumber: 'INV-2025-0089',
      lineItems: const [
        SaleLineItem(slabId: 's_008', agreedPricePerSqm: 160.0, areaSqm: 4.340),
        SaleLineItem(slabId: 's_010', agreedPricePerSqm: 175.0, areaSqm: 4.640),
      ],
    ),
  ];

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static int get totalSlabs    => slabs.length;
  static int get availableSlabs => slabs.where((s) => s.status == SlabStatus.available).length;
  static int get reservedSlabs  => slabs.where((s) => s.status == SlabStatus.reserved).length;
  static int get soldSlabs      => slabs.where((s) => s.status == SlabStatus.sold).length;
  static int get defectSlabs    => slabs.where((s) => s.hasDefect).length;

  static double get totalInventoryValue => slabs.fold(0.0, (sum, slab) {
    final mat = materials.firstWhere((m) => m.id == slab.materialId, orElse: () => materials.first);
    return sum + (mat.pricePerSqm * slab.areaSqm);
  });

  static MaterialItem materialForSlab(Slab slab) =>
      materials.firstWhere((m) => m.id == slab.materialId);

  static Category categoryForMaterial(MaterialItem mat) =>
      categories.firstWhere((c) => c.id == mat.categoryId);
}
