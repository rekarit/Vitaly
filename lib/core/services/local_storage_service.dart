import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category_model.dart';
import '../models/material_item.dart';
import '../models/slab.dart';
import '../models/rack.dart';
import '../models/customer.dart';
import '../models/reservation.dart';
import '../models/sale.dart';
import '../models/return_item.dart';
import '../models/payment_record.dart';
import '../models/material_audit_record.dart';

/// Complete Local Persistence Layer for Vitaly App.
/// Guarantees that data is never wiped on logout, app reload, or network interruption.
class LocalStorageService {
  static const _keyMaterials = 'vitaly_materials_v1';
  static const _keySlabs = 'vitaly_slabs_v1';
  static const _keyCustomers = 'vitaly_customers_v1';
  static const _keyReservations = 'vitaly_reservations_v1';
  static const _keySales = 'vitaly_sales_v1';
  static const _keyReturns = 'vitaly_returns_v1';
  static const _keyPayments = 'vitaly_payments_v1';
  static const _keyAudits = 'vitaly_audits_v1';
  static const _keyCategories = 'vitaly_categories_v1';
  static const _keyRacks = 'vitaly_racks_v1';

  // ── Materials ─────────────────────────────────────────────────────────────
  static Future<void> saveMaterials(List<MaterialItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list.map((m) => {
        'id': m.id,
        'name': m.name,
        'categoryId': m.categoryId,
        'categoryCode': m.categoryCode,
        'materialCode': m.materialCode,
        'stoneType': m.stoneType,
        'origin': m.origin,
        'finish': m.finish,
        'referenceCode': m.referenceCode,
        'erpDescription': m.erpDescription,
        'erpUnit': m.erpUnit,
        'displayLabel': m.displayLabel,
        'totalAreaSqm': m.totalAreaSqm,
        'totalSlabs': m.totalSlabs,
        'pricePerSqm': m.pricePerSqm,
        'colorFamily': m.colorFamily,
        'imageUrl': m.imageUrl,
      }).toList();
      await prefs.setString(_keyMaterials, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving materials locally: $e');
    }
  }

  static Future<List<MaterialItem>> loadMaterials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyMaterials);
      if (str == null || str.isEmpty) return [];
      final List raw = jsonDecode(str);
      return raw.map((json) {
        return MaterialItem(
          id: json['id']?.toString() ?? '',
          name: json['name']?.toString() ?? '',
          categoryId: json['categoryId']?.toString() ?? 'Quartzite / Crystal',
          categoryCode: (json['categoryCode'] as num?)?.toInt() ?? 12,
          materialCode: json['materialCode']?.toString(),
          stoneType: json['stoneType']?.toString(),
          origin: json['origin']?.toString() ?? 'Unknown',
          finish: json['finish']?.toString() ?? 'Polish',
          referenceCode: json['referenceCode']?.toString(),
          erpDescription: json['erpDescription']?.toString() ?? '',
          erpUnit: json['erpUnit']?.toString() ?? 'sqm',
          displayLabel: json['displayLabel']?.toString() ?? '-',
          totalAreaSqm: (json['totalAreaSqm'] as num?)?.toDouble() ?? 0.0,
          totalSlabs: (json['totalSlabs'] as num?)?.toInt() ?? 0,
          pricePerSqm: (json['pricePerSqm'] as num?)?.toDouble() ?? 100.0,
          colorFamily: json['colorFamily']?.toString(),
          imageUrl: json['imageUrl']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading materials locally: $e');
      return [];
    }
  }

  // ── Slabs ─────────────────────────────────────────────────────────────────
  static Future<void> saveSlabs(List<Slab> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list.map((s) => s.toJson()).toList();
      await prefs.setString(_keySlabs, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving slabs locally: $e');
    }
  }

  static Future<List<Slab>> loadSlabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keySlabs);
      if (str == null || str.isEmpty) return [];
      final List raw = jsonDecode(str);
      return raw
          .map((json) => Slab.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error loading slabs locally: $e');
      return [];
    }
  }

  // ── Customers ─────────────────────────────────────────────────────────────
  static Future<void> saveCustomers(List<Customer> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list.map((c) => c.toJson()).toList();
      await prefs.setString(_keyCustomers, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving customers locally: $e');
    }
  }

  static Future<List<Customer>> loadCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyCustomers);
      if (str == null || str.isEmpty) return [];
      final List raw = jsonDecode(str);
      return raw.map((json) => Customer.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      debugPrint('Error loading customers locally: $e');
      return [];
    }
  }

  // ── Reservations ──────────────────────────────────────────────────────────
  static Future<void> saveReservations(List<Reservation> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list.map((r) => {
        'id': r.id,
        'customerId': r.customerId,
        'slabIds': r.slabIds,
        'reservedAt': r.reservedAt.toIso8601String(),
        'expiresAt': r.expiresAt.toIso8601String(),
        'status': r.status.name,
        'depositAmount': r.depositAmount,
        'notes': r.notes,
      }).toList();
      await prefs.setString(_keyReservations, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving reservations locally: $e');
    }
  }

  static Future<List<Reservation>> loadReservations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyReservations);
      if (str == null || str.isEmpty) return [];
      final List raw = jsonDecode(str);
      return raw.map((json) {
        final statusStr = json['status']?.toString() ?? 'active';
        ReservationStatus status = ReservationStatus.active;
        if (statusStr.contains('convert')) {
          status = ReservationStatus.converted;
        } else if (statusStr.contains('expir')) {
          status = ReservationStatus.expired;
        } else if (statusStr.contains('cancel')) {
          status = ReservationStatus.cancelled;
        }

        return Reservation(
          id: json['id']?.toString() ?? '',
          customerId: json['customerId']?.toString() ?? '',
          slabIds: (json['slabIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
          reservedAt: json['reservedAt'] != null
              ? DateTime.tryParse(json['reservedAt'].toString()) ?? DateTime.now()
              : DateTime.now(),
          expiresAt: json['expiresAt'] != null
              ? DateTime.tryParse(json['expiresAt'].toString()) ?? DateTime.now().add(const Duration(days: 7))
              : DateTime.now().add(const Duration(days: 7)),
          status: status,
          depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0.0,
          notes: json['notes']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading reservations locally: $e');
      return [];
    }
  }

  // ── Sales ─────────────────────────────────────────────────────────────────
  static Future<void> saveSales(List<Sale> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list.map((s) => {
        'id': s.id,
        'customerId': s.customerId,
        'lineItems': s.lineItems.map((li) => {
          'slabId': li.slabId,
          'agreedPricePerSqm': li.agreedPricePerSqm,
          'areaSqm': li.areaSqm,
        }).toList(),
        'saleDate': s.saleDate.toIso8601String(),
        'status': s.status.name,
        'paymentMethod': s.paymentMethod.name,
        'discountPercent': s.discountPercent,
        'amountPaid': s.amountPaid,
        'pickedUp': s.pickedUp,
        'pickupDate': s.pickupDate?.toIso8601String(),
        'invoiceNumber': s.invoiceNumber,
        'notes': s.notes,
        'fromReservationId': s.fromReservationId,
      }).toList();
      await prefs.setString(_keySales, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving sales locally: $e');
    }
  }

  static Future<List<Sale>> loadSales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keySales);
      if (str == null || str.isEmpty) return [];
      final List raw = jsonDecode(str);
      return raw.map((json) {
        final statusStr = json['status']?.toString() ?? 'confirmed';
        SaleStatus status = SaleStatus.confirmed;
        if (statusStr.contains('draft')) status = SaleStatus.draft;
        if (statusStr.contains('invoice')) status = SaleStatus.invoiced;
        if (statusStr.contains('paid')) status = SaleStatus.paid;
        if (statusStr.contains('deliver')) status = SaleStatus.delivered;

        final pmStr = json['paymentMethod']?.toString() ?? 'cash';
        PaymentMethod pm = PaymentMethod.cash;
        if (pmStr.contains('bank')) pm = PaymentMethod.bankTransfer;
        if (pmStr.contains('credit')) pm = PaymentMethod.creditCard;
        if (pmStr.contains('check')) pm = PaymentMethod.check;

        final lineItemsRaw = json['lineItems'] as List? ?? [];
        final lineItems = lineItemsRaw.map((li) {
          return SaleLineItem(
            slabId: li['slabId']?.toString() ?? '',
            agreedPricePerSqm: (li['agreedPricePerSqm'] as num?)?.toDouble() ?? 0.0,
            areaSqm: (li['areaSqm'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

        return Sale(
          id: json['id']?.toString() ?? '',
          customerId: json['customerId']?.toString() ?? '',
          lineItems: lineItems,
          saleDate: json['saleDate'] != null
              ? DateTime.tryParse(json['saleDate'].toString()) ?? DateTime.now()
              : DateTime.now(),
          status: status,
          paymentMethod: pm,
          discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
          amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
          pickedUp: json['pickedUp'] == true,
          pickupDate: json['pickupDate'] != null
              ? DateTime.tryParse(json['pickupDate'].toString())
              : null,
          invoiceNumber: json['invoiceNumber']?.toString(),
          notes: json['notes']?.toString(),
          fromReservationId: json['fromReservationId']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading sales locally: $e');
      return [];
    }
  }

  // ── Returns ───────────────────────────────────────────────────────────────
  static Future<void> saveReturns(List<ReturnItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list.map((r) => {
        'id': r.id,
        'returnDate': r.returnDate.toIso8601String(),
        'originalSaleId': r.originalSaleId,
        'customerId': r.customerId,
        'materialCode': r.materialCode,
        'inventoryId': r.inventoryId,
        'quantityReturnedSqm': r.quantityReturnedSqm,
        'returnReason': r.returnReason,
        'condition': r.condition,
        'restockToInventory': r.restockToInventory,
        'status': r.status.name,
        'notes': r.notes,
      }).toList();
      await prefs.setString(_keyReturns, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving returns locally: $e');
    }
  }

  static Future<List<ReturnItem>> loadReturns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyReturns);
      if (str == null || str.isEmpty) return [];
      final List raw = jsonDecode(str);
      return raw.map((json) {
        final statusStr = json['status']?.toString() ?? 'completed';
        ReturnStatus status = ReturnStatus.completed;
        if (statusStr.contains('pending')) status = ReturnStatus.pending;
        if (statusStr.contains('approved')) status = ReturnStatus.approved;
        if (statusStr.contains('rejected')) status = ReturnStatus.rejected;

        return ReturnItem(
          id: json['id']?.toString() ?? '',
          returnDate: json['returnDate'] != null
              ? DateTime.tryParse(json['returnDate'].toString()) ?? DateTime.now()
              : DateTime.now(),
          originalSaleId: json['originalSaleId']?.toString(),
          customerId: json['customerId']?.toString() ?? '',
          materialCode: json['materialCode']?.toString(),
          inventoryId: json['inventoryId']?.toString(),
          quantityReturnedSqm: (json['quantityReturnedSqm'] as num?)?.toDouble() ?? 0.0,
          returnReason: json['returnReason']?.toString() ?? '',
          condition: json['condition']?.toString() ?? '',
          restockToInventory: json['restockToInventory'] ?? true,
          status: status,
          notes: json['notes']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading returns locally: $e');
      return [];
    }
  }

  // ── Payments ──────────────────────────────────────────────────────────────
  static Future<void> savePayments(List<PaymentRecord> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list.map((p) => {
        'id': p.id,
        'paymentDate': p.paymentDate.toIso8601String(),
        'customerId': p.customerId,
        'relatedSaleId': p.relatedSaleId,
        'relatedReservationId': p.relatedReservationId,
        'amountPaid': p.amountPaid,
        'paymentType': p.paymentType,
        'notes': p.notes,
      }).toList();
      await prefs.setString(_keyPayments, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving payments locally: $e');
    }
  }

  static Future<List<PaymentRecord>> loadPayments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyPayments);
      if (str == null || str.isEmpty) return [];
      final List raw = jsonDecode(str);
      return raw.map((json) {
        return PaymentRecord(
          id: json['id']?.toString() ?? '',
          paymentDate: json['paymentDate'] != null
              ? DateTime.tryParse(json['paymentDate'].toString()) ?? DateTime.now()
              : DateTime.now(),
          customerId: json['customerId']?.toString() ?? '',
          relatedSaleId: json['relatedSaleId']?.toString(),
          relatedReservationId: json['relatedReservationId']?.toString(),
          amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
          paymentType: json['paymentType']?.toString() ?? 'Cash',
          notes: json['notes']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading payments locally: $e');
      return [];
    }
  }

  // ── Audits ────────────────────────────────────────────────────────────────
  static Future<void> saveAudits(Map<String, MaterialAuditRecord> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = map.values.map((a) => {
        'materialId': a.materialId,
        'codeText': a.codeText,
        'materialName': a.materialName,
        'categoryCode': a.categoryCode,
        'physicalSqm': a.physicalSqm,
        'isCounted': a.isCounted,
        'erpInSqm': a.erpInSqm,
        'erpOutSqm': a.erpOutSqm,
        'erpBalanceOverride': a.erpBalanceOverride,
        'appSqmOverride': a.appSqmOverride,
        'lastErpUpdate': a.lastErpUpdate,
        'notes': a.notes,
        'lastCountDate': a.lastCountDate,
      }).toList();
      await prefs.setString(_keyAudits, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving audits locally: $e');
    }
  }

  static Future<Map<String, MaterialAuditRecord>> loadAudits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyAudits);
      if (str == null || str.isEmpty) return {};
      final List raw = jsonDecode(str);
      final Map<String, MaterialAuditRecord> result = {};
      for (final json in raw) {
        final a = MaterialAuditRecord(
          materialId: json['materialId']?.toString() ?? '',
          codeText: json['codeText']?.toString() ?? '',
          materialName: json['materialName']?.toString() ?? '',
          categoryCode: (json['categoryCode'] as num?)?.toInt() ?? 12,
          physicalSqm: (json['physicalSqm'] as num?)?.toDouble(),
          isCounted: json['isCounted'] == true,
          erpInSqm: (json['erpInSqm'] as num?)?.toDouble() ?? 0.0,
          erpOutSqm: (json['erpOutSqm'] as num?)?.toDouble() ?? 0.0,
          erpBalanceOverride: (json['erpBalanceOverride'] as num?)?.toDouble(),
          appSqmOverride: (json['appSqmOverride'] as num?)?.toDouble(),
          lastErpUpdate: json['lastErpUpdate']?.toString() ?? '',
          notes: json['notes']?.toString() ?? '',
          lastCountDate: json['lastCountDate']?.toString() ?? '',
        );
        result[a.materialId] = a;
      }
      return result;
    } catch (e) {
      debugPrint('Error loading audits locally: $e');
      return {};
    }
  }

  // ── Categories & Racks ────────────────────────────────────────────────────
  static Future<void> saveCategories(List<CategoryModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list.map((c) => {
        'categoryCode': c.categoryCode,
        'categoryName': c.categoryName,
        'categoryHeader': c.categoryHeader,
      }).toList();
      await prefs.setString(_keyCategories, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving categories locally: $e');
    }
  }

  static Future<List<CategoryModel>> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyCategories);
      if (str == null || str.isEmpty) return [];
      final List raw = jsonDecode(str);
      return raw.map((json) {
        return CategoryModel(
          categoryCode: (json['categoryCode'] as num?)?.toInt() ?? 12,
          categoryName: json['categoryName']?.toString() ?? '',
          categoryHeader: json['categoryHeader']?.toString() ?? '-',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading categories locally: $e');
      return [];
    }
  }

  static Future<void> saveRacks(List<Rack> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list.map((r) => {
        'rackCode': r.rackCode,
        'rackName': r.rackName,
        'warehouse': r.warehouse,
        'active': r.active,
        'locationType': r.locationType,
      }).toList();
      await prefs.setString(_keyRacks, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving racks locally: $e');
    }
  }

  static Future<List<Rack>> loadRacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyRacks);
      if (str == null || str.isEmpty) return [];
      final List raw = jsonDecode(str);
      return raw.map((json) {
        return Rack(
          rackCode: json['rackCode']?.toString() ?? '',
          rackName: json['rackName']?.toString() ?? '',
          warehouse: json['warehouse']?.toString() ?? 'Warehouse',
          active: json['active']?.toString() ?? 'Y',
          locationType: json['locationType']?.toString() ?? 'Yard',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading racks locally: $e');
      return [];
    }
  }

  // ── Wipe Local Cache ──────────────────────────────────────────────────────
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyMaterials);
      await prefs.remove(_keySlabs);
      await prefs.remove(_keyCustomers);
      await prefs.remove(_keyReservations);
      await prefs.remove(_keySales);
      await prefs.remove(_keyReturns);
      await prefs.remove(_keyPayments);
      await prefs.remove(_keyAudits);
      await prefs.remove(_keyCategories);
      await prefs.remove(_keyRacks);
    } catch (e) {
      debugPrint('Error clearing local cache: $e');
    }
  }
}
