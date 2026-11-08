import 'package:flutter_test/flutter_test.dart';
import 'package:vitaly_app/core/state/app_state.dart';
import 'package:vitaly_app/core/utils/export_utils.dart';

void main() {
  group('CategoryCheck & DataChek Alignment Tests', () {
    test('AppState seeds CategoryCheck data matching user screenshots exactly', () {
      final state = AppState();

      // Check Category 12 seed records
      final cat12Audits = state.materialAudits.values.where((a) => a.categoryCode == 12).toList();
      expect(cat12Audits.isNotEmpty, isTrue);

      final totalErpCat12 = cat12Audits.fold(0.0, (s, a) => s + a.erpBalanceSqm);
      final totalAppCat12 = cat12Audits.fold(0.0, (s, a) => s + (a.appSqmOverride ?? 0.0));

      // 2,767.10 and 1,736.90 from Image 1
      expect(totalErpCat12, closeTo(2767.10, 0.01));
      expect(totalAppCat12, closeTo(1736.90, 0.01));

      // Check specific items from Image 2
      final item1201 = state.materialAudits['1201'];
      expect(item1201, isNotNull);
      expect(item1201!.erpBalanceSqm, closeTo(92.34, 0.01));
      expect(item1201.appSqmOverride, closeTo(347.29, 0.01));
      expect(item1201.appVsErp, closeTo(254.95, 0.01));
      expect(item1201.erpInSqm, closeTo(101.64, 0.01));
      expect(item1201.erpOutSqm, closeTo(9.30, 0.01));
      expect(item1201.lastErpUpdate, equals('6/20/2026'));
      expect(item1201.notes, equals('Imported from ERP movement summary'));
      expect(item1201.materialName, equals('CALACATTA GOLD'));
      expect(item1201.displayName, equals('1201 - CALACATTA GOLD'));

      // Check item 1217 from Screenshot 1
      final item1217 = state.materialAudits['1217'];
      expect(item1217, isNotNull);
      expect(item1217!.erpBalanceSqm, closeTo(100.10, 0.01));
      expect(item1217.appSqmOverride, closeTo(0.00, 0.01));
      expect(item1217.appVsErp, closeTo(-100.10, 0.01));
      expect(item1217.erpInSqm, closeTo(107.25, 0.01));
      expect(item1217.erpOutSqm, closeTo(7.15, 0.01));
    }, skip: 'Mock audits removed per user request for clean state');

    test('ExportUtils generates valid CSV for CategoryCheck', () {
      final headers = ['CategoryCode', 'Cat_ERP_sqm', 'Cat_App_sqm'];
      final rows = [
        [12, '2,767.10', '1,736.90'],
        [13, '4,896.89', '0.00'],
      ];

      final csv = ExportUtils.generateCsv(headers: headers, rows: rows);
      expect(csv, contains('CategoryCode,Cat_ERP_sqm,Cat_App_sqm'));
      expect(csv, contains('12,"2,767.10","1,736.90"'));
    });
  });
}
