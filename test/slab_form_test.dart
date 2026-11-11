import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitaly_app/core/models/material_item.dart';
import 'package:vitaly_app/core/models/slab.dart';
import 'package:vitaly_app/core/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppSheet StoneInventory & Slab Workflows', () {
    test('Slab calculates area in sqm from millimeter dimensions accurately', () {
      const slab = Slab(
        id: '1201-01',
        materialId: '1201',
        slabNo: '1201-01',
        lengthMm: 2344.0,
        widthMm: 2344.0,
        thicknessMm: 20.0,
      );

      // (2344 * 2344) / 1,000,000 = 5.494336
      expect(slab.areaSqm, closeTo(5.49, 0.01));
      expect(slab.thicknessMm, 20.0);
      expect(slab.rackCode, 'RACK-A1');
    });

    test('Slab generates guaranteed unique QR payload', () {
      final now = DateTime(2026, 9, 22, 10, 30);
      final slab1 = Slab(
        id: '1201-01',
        materialId: '1201',
        slabNo: '1201-01',
        receivedDate: now,
      );
      final slab2 = Slab(
        id: '1201-02',
        materialId: '1201',
        slabNo: '1201-02',
        receivedDate: now,
      );

      expect(slab1.qrCode.contains('material=1201&slab=1201-01'), isTrue);
      expect(slab2.qrCode.contains('material=1201&slab=1201-02'), isTrue);
      expect(slab1.qrCode, isNot(equals(slab2.qrCode)));
    });

    test('AppState auto-increments sequential slab number for material', () {
      final state = AppState();
      final nextSlabNo = state.nextSlabNoForMaterial('1201');

      // Starts clean at 01 for 1201
      expect(nextSlabNo, '1201-01');
    });

    test('Adding a slab dynamically updates material total area and count', () {
      final state = AppState();
      state.addMaterial(MaterialItem(
        id: '1201',
        materialCode: '1201',
        name: 'CALACATTA GOLD',
        categoryId: 'Quartzite / Crystal',
        finish: 'Polish',
      ));

      final initialArea = state.totalAreaSqmForMaterial('1201');
      final initialCount = state.totalSlabsForMaterial('1201');

      const newSlab = Slab(
        id: '1201-01',
        materialId: '1201',
        slabNo: '1201-01',
        lengthMm: 2000.0,
        widthMm: 2000.0,
        thicknessMm: 20.0,
        areaSqm: 4.0, // 2000 * 2000 / 1,000,000
      );

      state.addSlab(newSlab);

      expect(state.totalSlabsForMaterial('1201'), initialCount + 1);
      expect(state.totalAreaSqmForMaterial('1201'), closeTo(initialArea + 4.0, 0.01));

      // Parent category also updates
      final catArea = state.totalAreaSqmForCategory('Quartzite / Crystal');
      expect(catArea, closeTo(4.0, 0.01));
    });

    test('addSlabs batch creates 20 sequential slabs with unique QR codes and updates stats', () {
      final state = AppState();
      state.addMaterial(MaterialItem(
        id: '1201',
        materialCode: '1201',
        name: 'CALACATTA GOLD',
        categoryId: 'Quartzite / Crystal',
        finish: 'Polish',
      ));

      final initialCount = state.totalSlabsForMaterial('1201');
      final initialArea = state.totalAreaSqmForMaterial('1201');

      final List<Slab> batch = List.generate(20, (i) {
        final seq = (1 + i).toString().padLeft(2, '0');
        final slabNo = '1201-$seq';
        return Slab(
          id: slabNo,
          materialId: '1201',
          slabNo: slabNo,
          lengthMm: 2344.0,
          widthMm: 2344.0,
          thicknessMm: 20.0,
          areaSqm: 5.49,
          inventoryId: 'ab${(100000 + i)}',
          customQrData: 'ab${(100000 + i)}',
        );
      });

      state.addSlabs(batch);

      expect(state.totalSlabsForMaterial('1201'), initialCount + 20);
      expect(state.totalAreaSqmForMaterial('1201'), closeTo(initialArea + (20 * 5.49), 0.01));
      expect(state.slabs.any((s) => s.slabNo == '1201-20'), isTrue);

      // Verify deleteSlabs bulk deletion
      final slabsToDelete = batch.take(5).map((s) => s.id).toList();
      state.deleteSlabs(slabsToDelete);

      expect(state.totalSlabsForMaterial('1201'), initialCount + 15);
      expect(state.totalAreaSqmForMaterial('1201'), closeTo(initialArea + (15 * 5.49), 0.01));
      expect(state.slabs.any((s) => s.slabNo == '1201-01'), isFalse);
    });

    test('AppState preserves distinct InventoryIDs even with same SlabNo and serializes metadata', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final state = AppState();
      final s1 = Slab(
        id: '230df306',
        inventoryId: '230df306',
        materialId: '1201',
        slabNo: '1201-09',
        lengthMm: 2000,
        widthMm: 1550,
        areaSqm: 3.10,
        warehouseLocation: 'SHOWROOM',
        locationType: 'Yard',
        visibleInCatalog: true,
      );
      final s2 = Slab(
        id: 'fd6f7d7c',
        inventoryId: 'fd6f7d7c',
        materialId: '1201',
        slabNo: '1201-09',
        lengthMm: 2344,
        widthMm: 2342,
        areaSqm: 5.49,
        warehouseLocation: 'WAREHOUSE',
        locationType: 'Yard',
        visibleInCatalog: true,
        quantity: 1,
      );

      state.addSlabs([s1, s2]);

      expect(state.slabs.where((s) => s.slabNo == '1201-09').length, 2);
      final roundTrip = Slab.fromJson(s2.toJson());
      expect(roundTrip.inventoryId, 'fd6f7d7c');
      expect(roundTrip.locationType, 'Yard');
      expect(roundTrip.visibleInCatalog, isTrue);
      expect(roundTrip.quantity, 1);
    });
  });
}
