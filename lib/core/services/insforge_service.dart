import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/category_model.dart';
import '../models/material_item.dart';
import '../models/slab.dart';
import '../models/customer.dart';
import '../models/reservation.dart';
import '../models/sale.dart';
import '../models/material_audit_record.dart';

class InsforgeService {
  static const String baseUrl = 'https://ufn3ge8i.us-east.insforge.app';
  static const String anonKey = 'ik_e1f7df29ef2eaccacd57140130f8ac09';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $anonKey',
        'apikey': anonKey,
      };

  static Map<String, String> get _patchHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $anonKey',
        'apikey': anonKey,
        'Prefer': 'return=representation',
      };

  // ── Categories ────────────────────────────────────────────────────────────
  static Future<List<CategoryModel>> getCategories() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/database/records/categories'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((json) {
          return CategoryModel(
            categoryCode: json['category_code'] is int
                ? json['category_code']
                : int.tryParse(json['category_code']?.toString() ?? '0') ?? 0,
            categoryName: json['category_name']?.toString() ?? '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
    return [];
  }

  static Future<bool> postCategory(CategoryModel cat) async {
    try {
      final payload = {
        'category_code': cat.categoryCode,
        'category_name': cat.categoryName,
      };

      final patchRes = await http.patch(
        Uri.parse('$baseUrl/api/database/records/categories?category_code=eq.${cat.categoryCode}'),
        headers: _patchHeaders,
        body: jsonEncode(payload),
      );

      if (patchRes.statusCode == 200 || patchRes.statusCode == 204) {
        if (patchRes.statusCode == 204) return true;
        try {
          final decoded = jsonDecode(patchRes.body);
          if (decoded is List && decoded.isNotEmpty) return true;
        } catch (_) {
          return true;
        }
      }

      final res = await http.post(
        Uri.parse('$baseUrl/api/database/records/categories'),
        headers: _headers,
        body: jsonEncode([payload]),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Error posting category: $e');
      return false;
    }
  }

  static Future<bool> deleteCategory(int categoryCode) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/database/records/categories?category_code=eq.$categoryCode'),
        headers: _headers,
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      return false;
    }
  }

  // ── Materials ─────────────────────────────────────────────────────────────
  static Future<List<MaterialItem>> getMaterials() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/database/records/materials'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((json) {
          final int catCode = json['category_code'] is int
              ? json['category_code']
              : int.tryParse(json['category_code']?.toString() ?? '12') ?? 12;
          final String matCodeStr = json['material_code']?.toString() ?? '';

          return MaterialItem(
            id: matCodeStr.isNotEmpty ? matCodeStr : (json['id']?.toString() ?? ''),
            name: json['material_name']?.toString() ?? '',
            categoryId: json['stone_type']?.toString() ?? 'Stone',
            categoryCode: catCode,
            materialCode: matCodeStr,
            stoneType: json['stone_type']?.toString() ?? 'Stone',
            finish: json['finish']?.toString() ?? 'Polish',
            imageUrl: json['material_image_url']?.toString(),
            erpDescription: json['erp_description']?.toString() ?? '',
            erpUnit: json['erp_unit']?.toString() ?? 'sqm',
            colorFamily: json['color_family']?.toString() ?? '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching materials: $e');
    }
    return [];
  }

  static Future<bool> postMaterial(MaterialItem item) async {
    try {
      final code = item.materialCode.isNotEmpty ? item.materialCode : item.id;
      final payload = {
        'material_code': code,
        'category_code': item.categoryCode,
        'material_name': item.name,
        'stone_type': item.stoneType,
        'finish': item.finish,
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty) 'material_image_url': item.imageUrl,
        'erp_description': item.erpDescription,
        'erp_unit': item.erpUnit,
        'color_family': item.colorFamily,
      };

      // Try update first (PATCH) if it exists with Prefer: return=representation
      final patchRes = await http.patch(
        Uri.parse('$baseUrl/api/database/records/materials?material_code=eq.$code'),
        headers: _patchHeaders,
        body: jsonEncode(payload),
      );

      if (patchRes.statusCode == 200 || patchRes.statusCode == 204) {
        if (patchRes.statusCode == 204) return true;
        try {
          final decoded = jsonDecode(patchRes.body);
          if (decoded is List && decoded.isNotEmpty) {
            return true; // Updated successfully
          }
        } catch (_) {
          return true;
        }
      }

      final res = await http.post(
        Uri.parse('$baseUrl/api/database/records/materials'),
        headers: _headers,
        body: jsonEncode([payload]),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Error posting material: $e');
      return false;
    }
  }

  static Future<bool> deleteMaterial(String materialCode) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/database/records/materials?material_code=eq.$materialCode'),
        headers: _headers,
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting material: $e');
      return false;
    }
  }

  // ── Stone Inventory (Slabs) ───────────────────────────────────────────────
  static Future<List<Slab>> getStoneInventory() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/database/records/stone_inventory'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((json) {
          final double lengthMm = (json['length_mm'] as num?)?.toDouble() ?? 0.0;
          final double widthMm = (json['width_mm'] as num?)?.toDouble() ?? 0.0;
          final double calculatedArea = (lengthMm * widthMm) / 1000000.0;
          final double areaSqm = (json['area_sqm'] as num?)?.toDouble() ?? calculatedArea;
          final String slabNo = json['slab_no']?.toString() ?? '';
          final String matId = json['material_code']?.toString() ?? '';
          final String statusStr = (json['status']?.toString() ?? 'available').toLowerCase();

          SlabStatus status = SlabStatus.available;
          if (statusStr.contains('unavail')) {
            status = SlabStatus.unavailable;
          } else if (statusStr.contains('reserv')) {
            status = SlabStatus.reserved;
          } else if (statusStr.contains('sold')) {
            status = SlabStatus.sold;
          } else if (statusStr.contains('damag')) {
            status = SlabStatus.damaged;
          }

          final double? reservedPrice = (json['reserved_price'] as num?)?.toDouble();

          return Slab(
            id: json['id']?.toString() ?? slabNo,
            materialId: matId,
            slabNo: slabNo,
            inventoryId: json['id']?.toString(),
            lengthMm: lengthMm,
            widthMm: widthMm,
            thicknessMm: (json['thickness_mm'] as num?)?.toDouble() ?? 20.0,
            areaSqm: areaSqm,
            warehouseLocation: json['rack_code']?.toString() ?? 'WAREHOUSE',
            rackCode: json['rack_code']?.toString() ?? 'WAREHOUSE',
            photoUrl: json['photo_url']?.toString(),
            status: status,
            defectNotes: json['notes']?.toString(),
            batchId: json['batch_id']?.toString(),
            reservedPrice: reservedPrice,
            receivedDate: json['received_date'] != null
                ? DateTime.tryParse(json['received_date'].toString()) ?? DateTime.now()
                : DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching stone inventory: $e');
    }
    return [];
  }

  static Future<bool> postStoneInventory(Slab slab) async {
    try {
      final payload = {
        'material_code': slab.materialId,
        'slab_no': slab.slabNo,
        'length_mm': slab.lengthMm,
        'width_mm': slab.widthMm,
        'thickness_mm': slab.thicknessMm,
        'area_sqm': slab.areaSqm,
        'rack_code': slab.rackCode,
        if (slab.photoUrl != null && slab.photoUrl!.isNotEmpty) 'photo_url': slab.photoUrl,
        'status': slab.status.name,
        if (slab.defectNotes != null && slab.defectNotes!.isNotEmpty) 'notes': slab.defectNotes,
        if (slab.batchId != null && slab.batchId!.isNotEmpty) 'batch_id': slab.batchId,
        if (slab.reservedPrice != null) 'reserved_price': slab.reservedPrice,
        'received_date': slab.receivedDate.toIso8601String().substring(0, 10),
      };

      // Try update first if slab_no exists with Prefer: return=representation
      final patchRes = await http.patch(
        Uri.parse('$baseUrl/api/database/records/stone_inventory?slab_no=eq.${slab.slabNo}'),
        headers: _patchHeaders,
        body: jsonEncode(payload),
      );

      if (patchRes.statusCode == 200 || patchRes.statusCode == 204) {
        if (patchRes.statusCode == 204) return true;
        try {
          final decoded = jsonDecode(patchRes.body);
          if (decoded is List && decoded.isNotEmpty) {
            return true; // Successfully updated existing slab
          }
        } catch (_) {
          return true;
        }
      }

      final res = await http.post(
        Uri.parse('$baseUrl/api/database/records/stone_inventory'),
        headers: _headers,
        body: jsonEncode([payload]),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Error posting slab to stone_inventory: $e');
      return false;
    }
  }

  static Future<bool> updateSlabStatus(
    String slabNoOrId,
    SlabStatus status, {
    double? reservedPrice,
    String? defectNotes,
  }) async {
    try {
      final payload = {
        'status': status.name,
        'reserved_price': reservedPrice,
        if (defectNotes != null && defectNotes.isNotEmpty) 'notes': defectNotes,
      };

      // Attempt update by slab_no or id
      var res = await http.patch(
        Uri.parse('$baseUrl/api/database/records/stone_inventory?slab_no=eq.$slabNoOrId'),
        headers: _headers,
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200 || res.statusCode == 204) return true;

      res = await http.patch(
        Uri.parse('$baseUrl/api/database/records/stone_inventory?id=eq.$slabNoOrId'),
        headers: _headers,
        body: jsonEncode(payload),
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error updating slab status: $e');
      return false;
    }
  }

  static Future<bool> deleteSlab(String slabNo) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/database/records/stone_inventory?slab_no=eq.$slabNo'),
        headers: _headers,
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting slab: $e');
      return false;
    }
  }

  // ── Customers ─────────────────────────────────────────────────────────────
  static Future<List<Customer>> getCustomers() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/database/records/customers'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((json) {
          return Customer(
            id: json['id']?.toString() ?? '',
            fullName: json['customer_name']?.toString() ?? '',
            phone: json['phone']?.toString() ?? '',
            address: json['address']?.toString() ?? '',
            city: json['address']?.toString() ?? '',
            company: json['customer_code']?.toString() ?? '',
            email: '',
            createdAt: DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }
    return [];
  }

  static Future<bool> postCustomer(Customer customer) async {
    try {
      final payload = {
        'customer_code': customer.id,
        'customer_name': customer.fullName,
        'phone': customer.phone,
        'address': customer.address.isNotEmpty ? customer.address : customer.city,
      };

      // Try update first if customer exists
      final patchRes = await http.patch(
        Uri.parse('$baseUrl/api/database/records/customers?customer_code=eq.${customer.id}'),
        headers: _patchHeaders,
        body: jsonEncode(payload),
      );

      if (patchRes.statusCode == 200 || patchRes.statusCode == 204) {
        if (patchRes.statusCode == 204) return true;
        try {
          final decoded = jsonDecode(patchRes.body);
          if (decoded is List && decoded.isNotEmpty) {
            return true;
          }
        } catch (_) {
          return true;
        }
      }

      final res = await http.post(
        Uri.parse('$baseUrl/api/database/records/customers'),
        headers: _headers,
        body: jsonEncode([payload]),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Error posting customer: $e');
      return false;
    }
  }

  static Future<bool> deleteCustomer(String customerId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/database/records/customers?customer_code=eq.$customerId'),
        headers: _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 204) return true;
      final res2 = await http.delete(
        Uri.parse('$baseUrl/api/database/records/customers?id=eq.$customerId'),
        headers: _headers,
      );
      return res2.statusCode == 200 || res2.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      return false;
    }
  }

  // ── Material Audits (Data Check) ───────────────────────────────────────────
  static Future<List<MaterialAuditRecord>> getAudits() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/database/records/material_audits'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((json) {
          return MaterialAuditRecord(
            materialId: json['material_id']?.toString() ?? '',
            codeText: json['code_text']?.toString() ?? json['material_id']?.toString() ?? '',
            materialName: json['material_name']?.toString() ?? '',
            categoryCode: (json['category_code'] as num?)?.toInt() ?? 12,
            physicalSqm: (json['physical_sqm'] as num?)?.toDouble(),
            isCounted: json['is_counted'] == true,
            erpInSqm: (json['erp_in_sqm'] as num?)?.toDouble() ?? 0.0,
            erpOutSqm: (json['erp_out_sqm'] as num?)?.toDouble() ?? 0.0,
            erpBalanceOverride: (json['erp_balance_override'] as num?)?.toDouble(),
            appSqmOverride: (json['app_sqm_override'] as num?)?.toDouble(),
            lastErpUpdate: json['last_erp_update']?.toString() ?? '',
            notes: json['notes']?.toString() ?? '',
            lastCountDate: json['last_count_date']?.toString() ?? '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching material audits: $e');
    }
    return [];
  }

  static Future<bool> saveAudit(MaterialAuditRecord record) async {
    try {
      final payload = {
        'material_id': record.materialId,
        'code_text': record.codeText,
        'material_name': record.materialName,
        'category_code': record.categoryCode,
        'physical_sqm': record.physicalSqm,
        'is_counted': record.isCounted,
        'erp_in_sqm': record.erpInSqm,
        'erp_out_sqm': record.erpOutSqm,
        'erp_balance_override': record.erpBalanceOverride,
        'app_sqm_override': record.appSqmOverride,
        'last_erp_update': record.lastErpUpdate,
        'notes': record.notes,
        'last_count_date': record.lastCountDate,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Try update first with Prefer: return=representation
      final patchRes = await http.patch(
        Uri.parse('$baseUrl/api/database/records/material_audits?material_id=eq.${record.materialId}'),
        headers: _patchHeaders,
        body: jsonEncode(payload),
      );

      if (patchRes.statusCode == 200 || patchRes.statusCode == 204) {
        if (patchRes.statusCode == 204) return true;
        try {
          final decoded = jsonDecode(patchRes.body);
          if (decoded is List && decoded.isNotEmpty) {
            return true; // Successfully updated
          }
        } catch (_) {
          return true;
        }
      }

      // If not updated, insert
      final postRes = await http.post(
        Uri.parse('$baseUrl/api/database/records/material_audits'),
        headers: _headers,
        body: jsonEncode([payload]),
      );
      return postRes.statusCode == 200 || postRes.statusCode == 201;
    } catch (e) {
      debugPrint('Error saving material audit: $e');
      return false;
    }
  }

  // ── Reservations ──────────────────────────────────────────────────────────
  static Future<List<Reservation>> getReservations() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/database/records/reservations'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((json) {
          final List<String> slabIds = [];
          if (json['slab_ids'] is List) {
            slabIds.addAll((json['slab_ids'] as List).map((e) => e.toString()));
          }
          final statusStr = (json['status']?.toString() ?? 'active').toLowerCase();
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
            customerId: json['customer_id']?.toString() ?? '',
            slabIds: slabIds,
            reservedAt: json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
            expiresAt: json['expiry_date'] != null
                ? DateTime.tryParse(json['expiry_date'].toString()) ?? DateTime.now().add(const Duration(days: 7))
                : DateTime.now().add(const Duration(days: 7)),
            status: status,
            notes: json['notes']?.toString(),
            depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching reservations: $e');
    }
    return [];
  }

  static Future<bool> postReservation({
    required String? customerId,
    required List<String> slabIds,
    required DateTime expiryDate,
    double depositAmount = 0.0,
    String? notes,
    String status = 'Active',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/database/records/reservations'),
        headers: _headers,
        body: jsonEncode([{
          if (customerId != null) 'customer_id': customerId,
          'slab_ids': slabIds,
          'expiry_date': expiryDate.toIso8601String().substring(0, 10),
          'deposit_amount': depositAmount,
          if (notes != null) 'notes': notes,
          'status': status,
        }]),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Error posting reservation: $e');
      return false;
    }
  }

  static Future<bool> updateReservationStatus(String resId, String status) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/api/database/records/reservations?id=eq.$resId'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error updating reservation status: $e');
      return false;
    }
  }

  static Future<bool> deleteReservation(String resId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/database/records/reservations?id=eq.$resId'),
        headers: _headers,
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting reservation: $e');
      return false;
    }
  }

  // ── Sales ─────────────────────────────────────────────────────────────────
  static Future<List<Sale>> getSales() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/database/records/sales'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((json) {
          final statusStr = (json['status']?.toString() ?? 'completed').toLowerCase();
          SaleStatus status = SaleStatus.confirmed;
          if (statusStr.contains('draft')) status = SaleStatus.draft;
          if (statusStr.contains('invoice')) status = SaleStatus.invoiced;
          if (statusStr.contains('paid') || statusStr.contains('complete')) status = SaleStatus.paid;
          if (statusStr.contains('deliver')) status = SaleStatus.delivered;

          final double amountPaid = (json['amount_paid'] as num?)?.toDouble() ?? 0.0;

          return Sale(
            id: json['id']?.toString() ?? '',
            customerId: json['customer_name']?.toString() ?? '',
            lineItems: [],
            saleDate: json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
            status: status,
            paymentMethod: PaymentMethod.cash,
            discountPercent: 0,
            amountPaid: amountPaid,
            pickedUp: json['is_picked_up'] == true,
            pickupDate: json['pickup_date'] != null ? DateTime.tryParse(json['pickup_date'].toString()) : null,
            invoiceNumber: json['invoice_no']?.toString(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching sales: $e');
    }
    return [];
  }

  static Future<bool> postSale(Sale sale) async {
    try {
      final double totalSqm = sale.totalSqm > 0 ? sale.totalSqm : 1.0;
      final double pricePerSqm = sale.total / totalSqm;
      final res = await http.post(
        Uri.parse('$baseUrl/api/database/records/sales'),
        headers: _headers,
        body: jsonEncode([{
          'price_sqm': pricePerSqm,
          'total_sqm': sale.totalSqm,
          'total_amount': sale.total,
          'amount_paid': sale.amountPaid,
          'balance_due': sale.balanceDue,
          'is_picked_up': sale.pickedUp,
          'status': sale.status.name,
          'customer_name': sale.customerId,
          'invoice_no': sale.invoiceNumber,
          'slab_ids': sale.lineItems.map((item) => item.slabId).toList(),
          if (sale.pickupDate != null)
            'pickup_date': sale.pickupDate!.toIso8601String().substring(0, 10),
        }]),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Error posting sale: $e');
      return false;
    }
  }

  static Future<bool> deleteSale(String saleId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/database/records/sales?id=eq.$saleId'),
        headers: _headers,
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting sale: $e');
      return false;
    }
  }

  // ── Cloud User Management & RBAC Sync ────────────────────────────────────
  static const String _usersSyncId = '__vitaly_system_users_sync__';
  static const String _logsSyncId = '__vitaly_system_logs_sync__';

  static Future<bool> syncUsersToCloud(List<Map<String, dynamic>> usersJson) async {
    try {
      final payload = {
        'material_id': _usersSyncId,
        'code_text': 'SYS_USERS',
        'material_name': 'Vitaly Users Registry',
        'category_code': 999,
        'notes': jsonEncode(usersJson),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final patchRes = await http.patch(
        Uri.parse('$baseUrl/api/database/records/material_audits?material_id=eq.$_usersSyncId'),
        headers: _patchHeaders,
        body: jsonEncode(payload),
      );

      if (patchRes.statusCode == 200 || patchRes.statusCode == 204) {
        return true;
      }

      final postRes = await http.post(
        Uri.parse('$baseUrl/api/database/records/material_audits'),
        headers: _headers,
        body: jsonEncode([payload]),
      );
      return postRes.statusCode == 200 || postRes.statusCode == 201;
    } catch (e) {
      debugPrint('Error syncing users to cloud: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchUsersFromCloud() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/database/records/material_audits?material_id=eq.$_usersSyncId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty && data.first['notes'] != null) {
          final notesStr = data.first['notes'].toString();
          if (notesStr.isNotEmpty) {
            final List decoded = jsonDecode(notesStr);
            return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching users from cloud: $e');
    }
    return null;
  }

  static Future<bool> syncLogsToCloud(List<Map<String, dynamic>> logsJson) async {
    try {
      final payload = {
        'material_id': _logsSyncId,
        'code_text': 'SYS_LOGS',
        'material_name': 'Vitaly System Activity Logs',
        'category_code': 999,
        'notes': jsonEncode(logsJson),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final patchRes = await http.patch(
        Uri.parse('$baseUrl/api/database/records/material_audits?material_id=eq.$_logsSyncId'),
        headers: _patchHeaders,
        body: jsonEncode(payload),
      );

      if (patchRes.statusCode == 200 || patchRes.statusCode == 204) {
        return true;
      }

      final postRes = await http.post(
        Uri.parse('$baseUrl/api/database/records/material_audits'),
        headers: _headers,
        body: jsonEncode([payload]),
      );
      return postRes.statusCode == 200 || postRes.statusCode == 201;
    } catch (e) {
      debugPrint('Error syncing logs to cloud: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchLogsFromCloud() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/database/records/material_audits?material_id=eq.$_logsSyncId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty && data.first['notes'] != null) {
          final notesStr = data.first['notes'].toString();
          if (notesStr.isNotEmpty) {
            final List decoded = jsonDecode(notesStr);
            return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching logs from cloud: $e');
    }
    return null;
  }

  // ── Permanent Data Erase / Reset ──────────────────────────────────────────
  static Future<bool> eraseAllData() async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/database/records/sales?id=not.is.null'),
        headers: _headers,
      );
      await http.delete(
        Uri.parse('$baseUrl/api/database/records/reservations?id=not.is.null'),
        headers: _headers,
      );
      await http.delete(
        Uri.parse('$baseUrl/api/database/records/stone_inventory?id=not.is.null'),
        headers: _headers,
      );
      await http.delete(
        Uri.parse('$baseUrl/api/database/records/material_audits?id=not.is.null'),
        headers: _headers,
      );
      await http.delete(
        Uri.parse('$baseUrl/api/database/records/customers?id=not.is.null'),
        headers: _headers,
      );
      await http.delete(
        Uri.parse('$baseUrl/api/database/records/materials?id=not.is.null'),
        headers: _headers,
      );
      await http.delete(
        Uri.parse('$baseUrl/api/database/records/categories?id=not.is.null'),
        headers: _headers,
      );
      return true;
    } catch (e) {
      debugPrint('Error erasing data from InsForge: $e');
      return false;
    }
  }
}

