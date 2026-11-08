import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitaly_app/core/models/material_item.dart';
import 'package:vitaly_app/core/models/slab.dart';
import 'package:vitaly_app/core/models/customer.dart';
import 'package:vitaly_app/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Local persistence guarantees data persists across sessions', () async {
    // 1. Create and save items
    final material = MaterialItem(
      id: '9901',
      name: 'SUPER TEST MARBLE',
      categoryId: 'Marble',
      categoryCode: 13,
      finish: 'Polish',
    );

    const slab = Slab(
      id: '9901-01',
      materialId: '9901',
      slabNo: '9901-01',
      lengthMm: 2500,
      widthMm: 1500,
      thicknessMm: 20,
    );

    final customer = Customer(
      id: 'C-999',
      fullName: 'VIP Client Test',
      company: 'Royal Stones',
      phone: '07500000000',
      email: 'client@test.com',
      city: 'Erbil',
      createdAt: DateTime.now(),
    );

    await LocalStorageService.saveMaterials([material]);
    await LocalStorageService.saveSlabs([slab]);
    await LocalStorageService.saveCustomers([customer]);

    // 2. Simulate re-launching app and loading from disk
    final loadedMats = await LocalStorageService.loadMaterials();
    final loadedSlabs = await LocalStorageService.loadSlabs();
    final loadedCusts = await LocalStorageService.loadCustomers();

    expect(loadedMats.length, 1);
    expect(loadedMats.first.materialCode, '9901');
    expect(loadedMats.first.name, 'SUPER TEST MARBLE');

    expect(loadedSlabs.length, 1);
    expect(loadedSlabs.first.slabNo, '9901-01');
    expect(loadedSlabs.first.lengthMm, 2500);

    expect(loadedCusts.length, 1);
    expect(loadedCusts.first.fullName, 'VIP Client Test');
  });
}
