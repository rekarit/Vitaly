import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitaly_app/core/models/category_model.dart';
import 'package:vitaly_app/core/models/material_item.dart';
import 'package:vitaly_app/core/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppSheet Materials Form & Category stock tests', () {
    test('MaterialItem contains all required AppSheet fields', () {
      final mat = MaterialItem(
        id: '1201',
        materialCode: '1201',
        name: 'CALACATTA GOLD',
        categoryId: 'Quartzite / Crystal',
        categoryCode: 12,
        stoneType: 'Quartzite',
        finish: 'Polish',
        referenceCode: '1201',
        erpDescription: 'Calacatta Gold Quartzite Premium Polished',
        erpUnit: 'sqm',
        displayLabel: '-',
        totalAreaSqm: 347.0,
        totalSlabs: 20,
        categoryAndName: 'Quartzite / Crystal - CALACATTA GOLD',
        stockSummary: '347 sqm • 20 slabs',
        codeAndFinish: '1201 - 347m² - Polish',
        categoryStock: '1606 sqm - 91 slabs',
      );

      expect(mat.materialCode, '1201');
      expect(mat.name, 'CALACATTA GOLD');
      expect(mat.stoneType, 'Quartzite');
      expect(mat.finish, 'Polish');
      expect(mat.erpUnit, 'sqm');
      expect(mat.displayLabel, '-');
      expect(mat.totalAreaSqm, 347.0);
      expect(mat.totalSlabs, 20);
      expect(mat.categoryAndName, 'Quartzite / Crystal - CALACATTA GOLD');
      expect(mat.stockSummary, '347 sqm • 20 slabs');
      expect(mat.codeAndFinish, '1201 - 347m² - Polish');
      expect(mat.categoryStock, '1606 sqm - 91 slabs');
    });

    test('AppState calculates category stock and auto-suggests next material code', () {
      final state = AppState();
      const cat = CategoryModel(categoryCode: 12, categoryName: 'Quartzite / Crystal');

      final mats = state.materialsForCategory(cat.categoryName);
      expect(mats.length, 0);

      final totalSlabs = state.totalSlabsForCategory(cat.categoryName);
      final totalArea = state.totalAreaSqmForCategory(cat.categoryName);
      expect(totalSlabs, 0);
      expect(totalArea, 0.0);

      final nextCode = state.nextMaterialCodeForCategory(cat);
      expect(nextCode, '1201');
    });

    test('Adding a new material through AppState persists correctly', () {
      final state = AppState();
      final newMat = MaterialItem(
        id: '1206',
        materialCode: '1206',
        name: 'EMERALD GREEN',
        categoryId: 'Quartzite / Crystal',
        categoryCode: 12,
        stoneType: 'Quartzite',
        finish: 'Polish',
        referenceCode: '1206',
        erpDescription: 'Exotic Emerald Green Quartzite',
        erpUnit: 'sqm',
        displayLabel: '-',
        totalAreaSqm: 0.0,
        totalSlabs: 0,
        categoryAndName: 'Quartzite / Crystal - EMERALD GREEN',
        stockSummary: '0 sqm • 0 slabs',
        codeAndFinish: '1206 - 0m² - Polish',
        categoryStock: '1606 sqm - 91 slabs',
      );

      state.addMaterial(newMat);
      final mats = state.materialsForCategory('Quartzite / Crystal');
      expect(mats.any((m) => m.materialCode == '1206'), isTrue);
    });
  });
}
