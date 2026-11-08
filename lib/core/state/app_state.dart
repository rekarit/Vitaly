import 'dart:async';
import 'package:flutter/foundation.dart';

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
import '../services/insforge_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../mock/mock_data.dart';

// -- APP STATE ---------------------------------------------------------------
// Single ChangeNotifier -- the ONE source of truth for the entire Vitaly App.
// Every mutation ends with notifyListeners() so all listening widgets rebuild.
// ----------------------------------------------------------------------------
class AppState extends ChangeNotifier {

  // -- Core collections ------------------------------------------------------
  final List<MaterialItem> materials    = [];
  final List<Slab> slabs                = [];
  final List<Customer>     customers    = [];
  final List<Reservation>  reservations = [];
  final List<Sale>         sales        = [];
  final List<ReturnItem>   returns      = [];
  final List<PaymentRecord> payments    = [];
  final Map<String, MaterialAuditRecord> materialAudits = {};

  bool isLoadingFromBackend = false;
  Timer? _realtimeSyncTimer;

  AppState() {
    _seedInitialAudits();
    _initData();
    _startRealtimePolling();
  }

  void _startRealtimePolling() {
    _realtimeSyncTimer?.cancel();
    // Fast 2-second real-time sync across devices without reloading!
    _realtimeSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      fetchFromInsforge(silent: true);
    });
  }

  @override
  void dispose() {
    _realtimeSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    await loadFromLocalStorage();
    await fetchFromInsforge();
  }

  Future<void> loadFromLocalStorage() async {
    try {
      final localCats = await LocalStorageService.loadCategories();
      if (localCats.isNotEmpty) {
        categoryModels.clear();
        categoryModels.addAll(localCats);
        categories.clear();
        categories.addAll(localCats.map((c) => c.categoryName));
      }

      final localMats = await LocalStorageService.loadMaterials();
      if (localMats.isNotEmpty) {
        materials.clear();
        materials.addAll(localMats);
      } else if (materials.isEmpty) {
        // Pre-load fixed AppSheet master stone catalog
        materials.addAll(MockData.masterMaterials);
        LocalStorageService.saveMaterials(materials);
      }

      final localSlabs = await LocalStorageService.loadSlabs();
      if (localSlabs.isNotEmpty) {
        slabs.clear();
        slabs.addAll(localSlabs);
        for (final m in materials) {
          _recalculateMaterialStats(m.id);
        }
      }

      final localCusts = await LocalStorageService.loadCustomers();
      if (localCusts.isNotEmpty) {
        customers.clear();
        customers.addAll(localCusts);
      }

      final localRes = await LocalStorageService.loadReservations();
      if (localRes.isNotEmpty) {
        reservations.clear();
        reservations.addAll(localRes);
      }

      final localSales = await LocalStorageService.loadSales();
      if (localSales.isNotEmpty) {
        sales.clear();
        sales.addAll(localSales);
      }

      final localReturns = await LocalStorageService.loadReturns();
      if (localReturns.isNotEmpty) {
        returns.clear();
        returns.addAll(localReturns);
      }

      final localPayments = await LocalStorageService.loadPayments();
      if (localPayments.isNotEmpty) {
        payments.clear();
        payments.addAll(localPayments);
      }

      final localAudits = await LocalStorageService.loadAudits();
      if (localAudits.isNotEmpty) {
        materialAudits.addAll(localAudits);
      }

      final localRacks = await LocalStorageService.loadRacks();
      if (localRacks.isNotEmpty) {
        racks.clear();
        racks.addAll(localRacks);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading from local storage: $e');
    }
  }

  Future<void> fetchFromInsforge({bool silent = false}) async {
    if (!silent) {
      isLoadingFromBackend = true;
      notifyListeners();
    }
    try {
      // 1. Live Sync Users & Roles across all devices in real-time
      await AuthService.instance.syncFromCloud();

      // 2. Global Distributed Cloud Sync (Zero downtime, 100% cross-device persistence)
      final cloudDb = await CloudSyncService.pullDatabase();
      if (cloudDb != null) {
        // Categories from Cloud
        if (cloudDb['categories'] is List) {
          final List cList = cloudDb['categories'];
          final map = {for (final c in categoryModels) c.categoryCode: c};
          for (final item in cList) {
            try {
              final cat = CategoryModel(
                categoryCode: item['categoryCode'] ?? item['category_code'] ?? 0,
                categoryName: item['categoryName'] ?? item['category_name'] ?? '',
              );
              map[cat.categoryCode] = cat;
              if (!categories.contains(cat.categoryName)) {
                categories.add(cat.categoryName);
              }
            } catch (_) {}
          }
          if (map.isNotEmpty) {
            categoryModels.clear();
            categoryModels.addAll(map.values);
            LocalStorageService.saveCategories(categoryModels);
          }
        }

        // Materials from Cloud
        if (cloudDb['materials'] is List) {
          final List mList = cloudDb['materials'];
          final map = {for (final m in materials) (m.materialCode.isNotEmpty ? m.materialCode : m.id): m};
          for (final item in mList) {
            try {
              final mat = MaterialItem.fromJson(Map<String, dynamic>.from(item as Map));
              final key = mat.materialCode.isNotEmpty ? mat.materialCode : mat.id;
              map[key] = mat;
            } catch (_) {}
          }
          if (map.isNotEmpty) {
            materials.clear();
            materials.addAll(map.values);
            LocalStorageService.saveMaterials(materials);
          }
        }

        // Slabs from Cloud
        if (cloudDb['slabs'] is List) {
          final List sList = cloudDb['slabs'];
          final map = {for (final s in slabs) s.slabNo: s};
          for (final item in sList) {
            try {
              final sl = Slab.fromJson(Map<String, dynamic>.from(item as Map));
              map[sl.slabNo] = sl;
            } catch (_) {}
          }
          if (map.isNotEmpty) {
            slabs.clear();
            slabs.addAll(map.values);
            for (final m in materials) {
              _recalculateMaterialStats(m.id);
            }
            LocalStorageService.saveSlabs(slabs);
          }
        }

        // Customers from Cloud
        if (cloudDb['customers'] is List) {
          final List custList = cloudDb['customers'];
          final map = {for (final c in customers) c.id: c};
          for (final item in custList) {
            try {
              final c = Customer.fromJson(Map<String, dynamic>.from(item as Map));
              map[c.id] = c;
            } catch (_) {}
          }
          if (map.isNotEmpty) {
            customers.clear();
            customers.addAll(map.values);
            LocalStorageService.saveCustomers(customers);
          }
        }

        // Reservations from Cloud
        if (cloudDb['reservations'] is List) {
          final List rList = cloudDb['reservations'];
          final map = {for (final r in reservations) r.id: r};
          for (final item in rList) {
            try {
              final r = Reservation.fromJson(Map<String, dynamic>.from(item as Map));
              map[r.id] = r;
            } catch (_) {}
          }
          if (map.isNotEmpty) {
            reservations.clear();
            reservations.addAll(map.values);
            LocalStorageService.saveReservations(reservations);
          }
        }

        // Sales from Cloud
        if (cloudDb['sales'] is List) {
          final List saList = cloudDb['sales'];
          final map = {for (final s in sales) s.id: s};
          for (final item in saList) {
            try {
              final s = Sale.fromJson(Map<String, dynamic>.from(item as Map));
              map[s.id] = s;
            } catch (_) {}
          }
          if (map.isNotEmpty) {
            sales.clear();
            sales.addAll(map.values);
            LocalStorageService.saveSales(sales);
          }
        }
      }

      // 3. Fallback / supplementary sync with InsForge backend
      final remoteCats = await InsforgeService.getCategories();
      if (remoteCats.isNotEmpty) {
        final map = {for (final c in categoryModels) c.categoryCode: c};
        for (final rc in remoteCats) {
          map[rc.categoryCode] = rc;
        }
        categoryModels.clear();
        categoryModels.addAll(map.values);
        for (final c in remoteCats) {
          if (!categories.contains(c.categoryName)) {
            categories.add(c.categoryName);
          }
        }
        LocalStorageService.saveCategories(categoryModels);
      }

      final remoteMats = await InsforgeService.getMaterials();
      if (remoteMats.isNotEmpty) {
        final map = {for (final m in materials) (m.materialCode.isNotEmpty ? m.materialCode : m.id): m};
        for (final rm in remoteMats) {
          final key = rm.materialCode.isNotEmpty ? rm.materialCode : rm.id;
          map[key] = rm;
        }
        materials.clear();
        materials.addAll(map.values);
        LocalStorageService.saveMaterials(materials);
      }

      final remoteSlabs = await InsforgeService.getStoneInventory();
      if (remoteSlabs.isNotEmpty) {
        final map = {for (final s in slabs) s.slabNo: s};
        for (final rs in remoteSlabs) {
          map[rs.slabNo] = rs;
        }
        slabs.clear();
        slabs.addAll(map.values);
        for (final m in materials) {
          _recalculateMaterialStats(m.id);
        }
        LocalStorageService.saveSlabs(slabs);
      }

      final remoteCusts = await InsforgeService.getCustomers();
      if (remoteCusts.isNotEmpty) {
        final map = {for (final c in customers) c.id: c};
        for (final rc in remoteCusts) {
          map[rc.id] = rc;
        }
        customers.clear();
        customers.addAll(map.values);
        LocalStorageService.saveCustomers(customers);
      }

      final remoteAudits = await InsforgeService.getAudits();
      if (remoteAudits.isNotEmpty) {
        for (final a in remoteAudits) {
          materialAudits[a.materialId] = a;
        }
        LocalStorageService.saveAudits(materialAudits);
      }

      final remoteRes = await InsforgeService.getReservations();
      if (remoteRes.isNotEmpty) {
        final map = {for (final r in reservations) r.id: r};
        for (final rr in remoteRes) {
          map[rr.id] = rr;
        }
        reservations.clear();
        reservations.addAll(map.values);
        LocalStorageService.saveReservations(reservations);
      }

      final remoteSales = await InsforgeService.getSales();
      if (remoteSales.isNotEmpty) {
        final map = {for (final s in sales) s.id: s};
        for (final rs in remoteSales) {
          map[rs.id] = rs;
        }
        sales.clear();
        sales.addAll(map.values);
        LocalStorageService.saveSales(sales);
      }
    } catch (e) {
      debugPrint('Error syncing from backend: $e');
    } finally {
      if (!silent) {
        isLoadingFromBackend = false;
      }
      notifyListeners();
    }
  }

  /// Pushes complete current state to Global Distributed Cloud (GitHub BaaS)
  /// so that any modification made on this device is immediately committed
  /// and visible to all other devices in real-time.
  Future<void> pushFullStateToCloud() async {
    try {
      final cloudDb = await CloudSyncService.pullDatabase() ?? {};

      // Union-merge users so we never overwrite mobile-created users, while honoring deleted users:
      final deletedUsers = AuthService.instance.deletedUsernames;
      final remoteUsers = (cloudDb['users'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final Map<String, Map<String, dynamic>> userMap = {};
      for (final u in remoteUsers) {
        final uname = u['username']?.toString().toLowerCase() ?? '';
        if (uname.isNotEmpty && !deletedUsers.contains(uname)) {
          userMap[uname] = u;
        }
      }
      for (final u in AuthService.instance.allUsersRaw()) {
        final uname = u['username']?.toString().toLowerCase() ?? '';
        if (uname.isNotEmpty && !deletedUsers.contains(uname)) {
          userMap[uname] = u;
        }
      }

      final payload = {
        'version': 2,
        'updated_at': DateTime.now().toIso8601String(),
        'users': userMap.values.toList(),
        'deleted_users': deletedUsers.toList(),
        'categories': categoryModels.map((c) => {
          'categoryCode': c.categoryCode,
          'categoryName': c.categoryName,
        }).toList(),
        'materials': materials.map((m) => m.toJson()).toList(),
        'slabs': slabs.map((s) => s.toJson()).toList(),
        'customers': customers.map((c) => c.toJson()).toList(),
        'reservations': reservations.map((r) => r.toJson()).toList(),
        'sales': sales.map((s) => s.toJson()).toList(),
      };
      CloudSyncService.debouncePush(payload);
    } catch (e) {
      debugPrint('Error in pushFullStateToCloud: $e');
    }
  }

  void _seedInitialAudits() {
    // Clean initial state: no hardcoded or mock audit records.
    // Audits and balances calculate when real materials and slabs are entered.
  }

  // -- Warehouse Racks (matching AppSheet Screenshots 4 & 5) ------------------
  final List<Rack> racks = [
    const Rack(
      rackCode: 'WAREHOUSE',
      rackName: 'Warehouse',
      warehouse: 'Warehouse',
      active: 'Y',
      locationType: 'Yard',
    ),
    const Rack(
      rackCode: 'SHOWROOM',
      rackName: 'Showroom',
      warehouse: 'Warehouse',
      active: 'Y',
      locationType: 'Field',
    ),
    const Rack(
      rackCode: 'RACK-A1',
      rackName: 'Rack A1',
      warehouse: 'Warehouse',
      active: 'Y',
      locationType: 'Yard',
    ),
    const Rack(
      rackCode: 'RACK-B1',
      rackName: 'Rack B1',
      warehouse: 'Warehouse',
      active: 'Y',
      locationType: 'Yard',
    ),
  ];

  // -- Root Category Models (Tree Trunk Architecture) ------------------------
  final List<CategoryModel> categoryModels = [
    const CategoryModel(categoryCode: 12, categoryName: 'Quartzite / Crystal', categoryHeader: 'Quartzite / Crystal - 12'),
    const CategoryModel(categoryCode: 13, categoryName: 'Marble', categoryHeader: 'Marble - 13'),
    const CategoryModel(categoryCode: 14, categoryName: 'Granite', categoryHeader: 'Granite - 14'),
    const CategoryModel(categoryCode: 15, categoryName: 'Onyx', categoryHeader: 'Onyx - 15'),
    const CategoryModel(categoryCode: 16, categoryName: 'Travertine', categoryHeader: 'Travertine - 16'),
    const CategoryModel(categoryCode: 17, categoryName: 'Crystal / Semi Precious', categoryHeader: 'Crystal / Semi Precious - 17'),
  ];

  // -- Global UI lists (DataEntry writes here -> all screens listen) ---------
  final List<String> categories = [
    'Quartzite / Crystal', 'Marble', 'Granite', 'Onyx',
    'Travertine', 'Crystal / Semi Precious',
  ];
  final List<String> finishes = [
    'Polish', 'Honed', 'Sandblast', 'Leather', 'Rock Design', 'Flamed & Brushed',
  ];

  // -- ID counters -----------------------------------------------------------
  int _matN  = 1;
  int _slabN = 1;
  int _resN  = 1;
  int _saleN = 1;
  int _custN = 1;

  String _matId()  => 'mat_${(_matN++).toString().padLeft(3, "0")}';
  String _slabId() => 's_${(_slabN++).toString().padLeft(4, "0")}';
  String _resId()  => 'res_${(_resN++).toString().padLeft(3, "0")}';
  String _saleId() => 'sale_${(_saleN++).toString().padLeft(3, "0")}';

  // -- Read helpers ----------------------------------------------------------
  int    get totalSlabs          => slabs.length;
  int    get availableSlabsCount => slabs.where((s) => s.status == SlabStatus.available).length;
  // Kept for backwards compat -- returns count not list.
  int    get availableSlabs      => availableSlabsCount;
  double get availableSqm        => slabs
      .where((s) => s.status == SlabStatus.available)
      .fold(0.0, (sum, s) => sum + s.areaSqm);

  // The authoritative available-slab list. Reservations & Sales MUST use this.
  List<Slab> get availableSlabsList =>
      slabs.where((s) => s.status == SlabStatus.available).toList();

  List<Slab> slabsForStatus(SlabStatus status) =>
      slabs.where((s) => s.status == status).toList();

  List<Slab> slabsForMaterial(String materialIdOrCode) {
    final mat = materialById(materialIdOrCode);
    final targetIds = {
      materialIdOrCode,
      if (mat != null) ...[mat.id, mat.materialCode],
    };
    return slabs.where((s) =>
        targetIds.contains(s.materialId) ||
        targetIds.any((id) => id.isNotEmpty && (s.id.startsWith('$id-') || s.slabNo.startsWith('$id-')))).toList();
  }

  int totalSlabsForMaterial(String materialId) {
    final matSlabs = slabsForMaterial(materialId);
    if (matSlabs.isNotEmpty) return matSlabs.length;
    final mat = materialById(materialId);
    return mat?.totalSlabs ?? 0;
  }

  double totalAreaSqmForMaterial(String materialId) {
    final matSlabs = slabsForMaterial(materialId);
    if (matSlabs.isNotEmpty) {
      return matSlabs.fold(0.0, (sum, s) => sum + s.areaSqm);
    }
    final mat = materialById(materialId);
    return mat?.totalAreaSqm ?? 0.0;
  }

  String nextSlabNoForMaterial(String materialCode) {
    final matSlabs = slabsForMaterial(materialCode);
    int highest = 0;
    for (final s in matSlabs) {
      final parts = s.slabNo.split('-');
      if (parts.length >= 2) {
        final numPart = int.tryParse(parts.last);
        if (numPart != null && numPart > highest) {
          highest = numPart;
        }
      }
    }
    final nextSeq = (highest > 0 ? highest : matSlabs.length) + 1;
    return '$materialCode-${nextSeq.toString().padLeft(2, "0")}';
  }

  MaterialItem? materialById(String id) {
    final q = id.trim();
    if (q.isEmpty) return null;
    final lower = q.toLowerCase();

    // 1. Direct match by id, materialCode, or name
    for (final m in materials) {
      if (m.id == q || m.materialCode == q) return m;
      if (m.id.toLowerCase() == lower || m.materialCode.toLowerCase() == lower) return m;
      if (m.name.toLowerCase() == lower) return m;
    }

    // 2. Prefixed match (e.g. "1202-01" or "1202 - CRISTALLO TIFFANY")
    if (q.contains('-')) {
      final prefix = q.split('-').first.trim().toLowerCase();
      for (final m in materials) {
        if (m.id.toLowerCase() == prefix || m.materialCode.toLowerCase() == prefix) return m;
      }
    }

    // 3. Fallback to Master catalog if not yet loaded in active materials list
    for (final m in MockData.masterMaterials) {
      if (m.id.toLowerCase() == lower || m.materialCode.toLowerCase() == lower) {
        addMaterial(m);
        return m;
      }
      if (q.contains('-')) {
        final prefix = q.split('-').first.trim().toLowerCase();
        if (m.id.toLowerCase() == prefix || m.materialCode.toLowerCase() == prefix) {
          addMaterial(m);
          return m;
        }
      }
    }

    return null;
  }

  Customer? customerById(String id) =>
      customers.cast<Customer?>().firstWhere((c) => c?.id == id, orElse: () => null);

  List<Slab> slabsByIds(List<String> ids) =>
      slabs.where((s) => ids.contains(s.id)).toList();

  // -- Category & Finish mutations -------------------------------------------
  int get nextCategoryCode {
    if (categoryModels.isEmpty) return 12;
    return categoryModels.map((c) => c.categoryCode).reduce((a, b) => a > b ? a : b) + 1;
  }

  void addCategoryModel(CategoryModel cat) {
    categoryModels.removeWhere((c) => c.categoryCode == cat.categoryCode || c.categoryName.toLowerCase() == cat.categoryName.toLowerCase());
    categoryModels.add(cat);
    if (!categories.contains(cat.categoryName)) {
      categories.add(cat.categoryName);
    }
    LocalStorageService.saveCategories(categoryModels);
    InsforgeService.postCategory(cat);
    pushFullStateToCloud();
    AuthService.instance.logActivity(
      actionType: 'CREATE',
      section: 'Categories',
      details: 'Created category "${cat.categoryName}" (Code: ${cat.categoryCode})',
    );
    notifyListeners();
  }

  void renameCategory(CategoryModel cat, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final oldName = cat.categoryName;
    final idx = categoryModels.indexWhere((c) => c.categoryCode == cat.categoryCode);
    if (idx != -1) {
      final updatedCat = categoryModels[idx].copyWith(
        categoryName: trimmed,
        categoryHeader: '$trimmed - ${cat.categoryCode}',
      );
      categoryModels[idx] = updatedCat;

      final catIdx = categories.indexOf(oldName);
      if (catIdx != -1) {
        categories[catIdx] = trimmed;
      } else if (!categories.contains(trimmed)) {
        categories.add(trimmed);
      }

      // Update materials belonging to oldName or categoryCode
      for (int i = 0; i < materials.length; i++) {
        final m = materials[i];
        if (m.categoryCode == cat.categoryCode || m.categoryId.toLowerCase() == oldName.toLowerCase()) {
          materials[i] = m.copyWith(
            categoryId: trimmed,
            categoryAndName: '$trimmed - ${m.name.toUpperCase()}',
          );
        }
      }

      LocalStorageService.saveCategories(categoryModels);
      LocalStorageService.saveMaterials(materials);
      pushFullStateToCloud();
      AuthService.instance.logActivity(
        actionType: 'UPDATE',
        section: 'Categories',
        details: 'Renamed category from "$oldName" to "$trimmed"',
      );
      notifyListeners();
    }
  }

  void deleteCategoryEmpty(CategoryModel cat) {
    categoryModels.removeWhere((c) => c.categoryCode == cat.categoryCode);
    categories.removeWhere((c) => c.toLowerCase() == cat.categoryName.toLowerCase());
    LocalStorageService.saveCategories(categoryModels);
    InsforgeService.deleteCategory(cat.categoryCode);
    AuthService.instance.logActivity(
      actionType: 'DELETE',
      section: 'Categories',
      details: 'Deleted empty category "${cat.categoryName}"',
    );
    notifyListeners();
  }

  void deleteCategoryCascade(CategoryModel cat) {
    final matsToDelete = materialsForCategory(cat.categoryName);
    final matIds = matsToDelete.map((m) => m.id).toSet();

    // Remove slabs belonging to these materials
    slabs.removeWhere((s) => matIds.contains(s.materialId));

    // Remove materials
    materials.removeWhere((m) => matIds.contains(m.id));

    // Remove category
    categoryModels.removeWhere((c) => c.categoryCode == cat.categoryCode);
    categories.removeWhere((c) => c.toLowerCase() == cat.categoryName.toLowerCase());

    LocalStorageService.saveCategories(categoryModels);
    LocalStorageService.saveMaterials(materials);
    LocalStorageService.saveSlabs(slabs);
    pushFullStateToCloud();

    InsforgeService.deleteCategory(cat.categoryCode);
    for (final mat in matsToDelete) {
      InsforgeService.deleteMaterial(mat.materialCode.isNotEmpty ? mat.materialCode : mat.id);
    }

    AuthService.instance.logActivity(
      actionType: 'DELETE',
      section: 'Categories',
      details: 'Deleted category "${cat.categoryName}" and cascaded items.',
    );
    notifyListeners();
  }

  void transferCategoryAndThenDelete(CategoryModel sourceCat, CategoryModel targetCat) {
    final matsToTransfer = materialsForCategory(sourceCat.categoryName);
    final matIds = matsToTransfer.map((m) => m.id).toSet();

    // Reassign materials to targetCat
    for (int i = 0; i < materials.length; i++) {
      final m = materials[i];
      if (matIds.contains(m.id)) {
        materials[i] = m.copyWith(
          categoryId: targetCat.categoryName,
          categoryCode: targetCat.categoryCode,
          categoryAndName: '${targetCat.categoryName} - ${m.name.toUpperCase()}',
        );
      }
    }

    // Remove source category
    categoryModels.removeWhere((c) => c.categoryCode == sourceCat.categoryCode);
    categories.removeWhere((c) => c.toLowerCase() == sourceCat.categoryName.toLowerCase());

    LocalStorageService.saveCategories(categoryModels);
    LocalStorageService.saveMaterials(materials);
    LocalStorageService.saveSlabs(slabs);
    pushFullStateToCloud();
    notifyListeners();
  }

  CategoryModel? categoryModelByName(String name) {
    try {
      return categoryModels.firstWhere((c) => c.categoryName.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  CategoryModel? categoryModelByCode(int code) {
    try {
      return categoryModels.firstWhere((c) => c.categoryCode == code);
    } catch (_) {
      return null;
    }
  }

  List<MaterialItem> materialsForCategory(String categoryName) {
    final catModel = categoryModelByName(categoryName);
    return materials
        .where((m) =>
            m.categoryId.toLowerCase() == categoryName.toLowerCase() ||
            m.colorFamily.toLowerCase() == categoryName.toLowerCase() ||
            (catModel != null && m.categoryCode == catModel.categoryCode))
        .toList();
  }

  int totalSlabsForCategory(String categoryName) {
    final catMats = materialsForCategory(categoryName);
    final matIds = catMats.map((m) => m.id).toSet();
    final slabCount = slabs.where((s) => matIds.contains(s.materialId)).length;
    if (slabCount > 0) return slabCount;
    return catMats.fold(0, (sum, m) => sum + m.totalSlabs);
  }

  double totalAreaSqmForCategory(String categoryName) {
    final catMats = materialsForCategory(categoryName);
    final matIds = catMats.map((m) => m.id).toSet();
    final slabArea = slabs.where((s) => matIds.contains(s.materialId)).fold(0.0, (sum, s) => sum + s.areaSqm);
    if (slabArea > 0) return slabArea;
    return catMats.fold(0.0, (sum, m) => sum + m.totalAreaSqm);
  }

  String nextMaterialCodeForCategory(CategoryModel cat) {
    final catMats = materialsForCategory(cat.categoryName);
    final prefix = cat.categoryCode;
    int highestSeq = 0;
    for (final m in catMats) {
      final codeStr = m.materialCode.trim();
      final numVal = int.tryParse(codeStr);
      if (numVal != null && codeStr.startsWith('$prefix')) {
        final seqPart = int.tryParse(codeStr.substring('$prefix'.length));
        if (seqPart != null && seqPart > highestSeq) {
          highestSeq = seqPart;
        }
      }
    }
    final nextSeq = highestSeq + 1;
    return '$prefix${nextSeq.toString().padLeft(2, "0")}';
  }

  void addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || categories.contains(trimmed)) return;
    categories.add(trimmed);
    if (!categoryModels.any((c) => c.categoryName.toLowerCase() == trimmed.toLowerCase())) {
      final nextCode = nextCategoryCode;
      final model = CategoryModel(categoryCode: nextCode, categoryName: trimmed);
      categoryModels.add(model);
      LocalStorageService.saveCategories(categoryModels);
      InsforgeService.postCategory(model);
    }
    notifyListeners();
  }

  void updateCategory(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final cat = categoryModelByName(oldName);
    if (cat != null) {
      renameCategory(cat, trimmed);
    } else {
      final idx = categories.indexOf(oldName);
      if (idx != -1) {
        categories[idx] = trimmed;
        LocalStorageService.saveCategories(categoryModels);
        notifyListeners();
      }
    }
  }

  void deleteCategory(String name) {
    final cat = categoryModelByName(name);
    if (cat != null) {
      deleteCategoryCascade(cat);
    } else {
      if (categories.remove(name)) {
        categoryModels.removeWhere((c) => c.categoryName.toLowerCase() == name.toLowerCase());
        LocalStorageService.saveCategories(categoryModels);
        notifyListeners();
      }
    }
  }

  void addFinish(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || finishes.contains(trimmed)) return;
    finishes.add(trimmed);
    notifyListeners();
  }

  // -- Material + Slab batch add (from Data Entry) ---------------------------
  void addBatch({required MaterialItem material, required List<Slab> batch}) {
    materials.add(material);
    slabs.addAll(batch);
    LocalStorageService.saveMaterials(materials);
    LocalStorageService.saveSlabs(slabs);
    InsforgeService.postMaterial(material);
    for (final s in batch) {
      InsforgeService.postStoneInventory(s);
    }
    notifyListeners();
  }

  // Legacy AppRepository compat -- DataEntryScreen calls these
  String nextMaterialId() => _matId();
  String nextSlabId()     => _slabId();
  void addMaterial(MaterialItem m) {
    final idx = materials.indexWhere((item) => item.id == m.id || item.materialCode == m.materialCode);
    final isNew = idx == -1;
    if (!isNew) {
      materials[idx] = m;
    } else {
      materials.add(m);
    }
    LocalStorageService.saveMaterials(materials);
    InsforgeService.postMaterial(m);
    pushFullStateToCloud();
    AuthService.instance.logActivity(
      actionType: isNew ? 'CREATE' : 'UPDATE',
      section: 'Materials',
      details: '${isNew ? "Added" : "Updated"} material "${m.name}" (${m.materialCode})',
    );
    notifyListeners();
  }

  void addSlab(Slab s) {
    final idx = slabs.indexWhere((item) => item.id == s.id || item.slabNo == s.slabNo);
    final isNew = idx == -1;
    if (!isNew) {
      slabs[idx] = s;
    } else {
      slabs.add(s);
    }
    _recalculateMaterialStats(s.materialId);
    LocalStorageService.saveSlabs(slabs);
    LocalStorageService.saveMaterials(materials);
    InsforgeService.postStoneInventory(s);
    pushFullStateToCloud();
    AuthService.instance.logActivity(
      actionType: isNew ? 'CREATE' : 'UPDATE',
      section: 'Stone Inventory',
      details: '${isNew ? "Added" : "Updated"} slab #${s.slabNo} (${s.areaSqm.toStringAsFixed(2)} sqm)',
    );
    notifyListeners();
  }

  void addSlabs(List<Slab> newSlabs) {
    if (newSlabs.isEmpty) return;
    for (final s in newSlabs) {
      final idx = slabs.indexWhere((item) => item.id == s.id || item.slabNo == s.slabNo);
      if (idx != -1) {
        slabs[idx] = s;
      } else {
        slabs.add(s);
      }
      InsforgeService.postStoneInventory(s);
    }
    final affectedMaterials = newSlabs.map((s) => s.materialId).toSet();
    for (final matId in affectedMaterials) {
      _recalculateMaterialStats(matId);
    }
    LocalStorageService.saveSlabs(slabs);
    LocalStorageService.saveMaterials(materials);
    pushFullStateToCloud();
    notifyListeners();
  }

  void updateSlabData(Slab updated) {
    final idx = slabs.indexWhere((s) => s.id == updated.id);
    if (idx != -1) {
      final oldMaterialId = slabs[idx].materialId;
      slabs[idx] = updated;
      _recalculateMaterialStats(updated.materialId);
      if (oldMaterialId != updated.materialId) {
        _recalculateMaterialStats(oldMaterialId);
      }
      LocalStorageService.saveSlabs(slabs);
      LocalStorageService.saveMaterials(materials);
      pushFullStateToCloud();
      notifyListeners();
    }
  }

  void updateMaterial(MaterialItem updated) {
    final idx = materials.indexWhere((m) => m.id == updated.id || m.materialCode == updated.materialCode);
    if (idx != -1) {
      materials[idx] = updated;
      _recalculateMaterialStats(updated.materialCode);
      LocalStorageService.saveMaterials(materials);
      InsforgeService.postMaterial(updated);
      pushFullStateToCloud();
      notifyListeners();
    }
  }

  void deleteMaterialEmpty(MaterialItem mat) {
    materials.removeWhere((m) => m.id == mat.id || m.materialCode == mat.materialCode);
    LocalStorageService.saveMaterials(materials);
    InsforgeService.deleteMaterial(mat.materialCode);
    AuthService.instance.logActivity(
      actionType: 'DELETE',
      section: 'Materials',
      details: 'Deleted empty material "${mat.name}" (${mat.materialCode})',
    );
    notifyListeners();
  }

  void deleteMaterialCascade(MaterialItem mat) {
    final slabsToDelete = slabsForMaterial(mat.materialCode);
    for (final s in slabsToDelete) {
      InsforgeService.deleteSlab(s.slabNo);
    }
    slabs.removeWhere((s) => s.materialId == mat.materialCode || s.materialId == mat.id);
    materials.removeWhere((m) => m.id == mat.id || m.materialCode == mat.materialCode);

    LocalStorageService.saveMaterials(materials);
    LocalStorageService.saveSlabs(slabs);
    InsforgeService.deleteMaterial(mat.materialCode);
    pushFullStateToCloud();
    AuthService.instance.logActivity(
      actionType: 'DELETE',
      section: 'Materials',
      details: 'Deleted material "${mat.name}" (${mat.materialCode}) and all related slabs.',
    );
    notifyListeners();
  }

  void transferMaterialSlabs(MaterialItem sourceMat, MaterialItem targetMat) {
    for (int i = 0; i < slabs.length; i++) {
      final s = slabs[i];
      if (s.materialId == sourceMat.materialCode || s.materialId == sourceMat.id) {
        final updatedSlab = s.copyWith(
          materialId: targetMat.materialCode,
        );
        slabs[i] = updatedSlab;
        InsforgeService.postStoneInventory(updatedSlab);
      }
    }
    _recalculateMaterialStats(sourceMat.materialCode);
    _recalculateMaterialStats(targetMat.materialCode);

    LocalStorageService.saveMaterials(materials);
    LocalStorageService.saveSlabs(slabs);
    notifyListeners();
  }

  void transferMaterialSlabsAndThenDelete(MaterialItem sourceMat, MaterialItem targetMat) {
    for (int i = 0; i < slabs.length; i++) {
      final s = slabs[i];
      if (s.materialId == sourceMat.materialCode || s.materialId == sourceMat.id) {
        final updatedSlab = s.copyWith(
          materialId: targetMat.materialCode,
        );
        slabs[i] = updatedSlab;
        InsforgeService.postStoneInventory(updatedSlab);
      }
    }
    materials.removeWhere((m) => m.id == sourceMat.id || m.materialCode == sourceMat.materialCode);
    _recalculateMaterialStats(targetMat.materialCode);

    LocalStorageService.saveMaterials(materials);
    LocalStorageService.saveSlabs(slabs);
    InsforgeService.deleteMaterial(sourceMat.materialCode);
    notifyListeners();
  }

  void deleteSlab(String slabId) {
    final idx = slabs.indexWhere((s) => s.id == slabId || s.slabNo == slabId);
    if (idx != -1) {
      final removed = slabs.removeAt(idx);
      InsforgeService.deleteSlab(removed.slabNo);
      _recalculateMaterialStats(removed.materialId);
      LocalStorageService.saveSlabs(slabs);
      LocalStorageService.saveMaterials(materials);
      pushFullStateToCloud();
      notifyListeners();
    }
  }

  void _recalculateMaterialStats(String materialId) {
    final matIdx = materials.indexWhere((m) => m.id == materialId || m.materialCode == materialId);
    if (matIdx != -1) {
      final matSlabs = slabsForMaterial(materialId);
      final totalArea = matSlabs.fold(0.0, (sum, item) => sum + item.areaSqm);
      final totalCount = matSlabs.length;
      final currentMat = materials[matIdx];
      materials[matIdx] = currentMat.copyWith(
        totalAreaSqm: totalArea,
        totalSlabs: totalCount,
        stockSummary: '${totalArea.toStringAsFixed(0)} sqm • $totalCount slabs',
        codeAndFinish: '${currentMat.materialCode} - ${totalArea.toStringAsFixed(0)}m² - ${currentMat.finish}',
      );
    }
  }

  Rack rackByCode(String code) {
    return racks.firstWhere(
      (r) => r.rackCode.toUpperCase() == code.trim().toUpperCase(),
      orElse: () => Rack(
        rackCode: code.toUpperCase(),
        rackName: code,
        warehouse: 'Warehouse',
        active: 'Y',
        locationType: 'Yard',
      ),
    );
  }

  void updateRack(Rack updated) {
    final idx = racks.indexWhere((r) => r.rackCode.toUpperCase() == updated.rackCode.toUpperCase());
    if (idx != -1) {
      racks[idx] = updated;
    } else {
      racks.add(updated);
    }
    LocalStorageService.saveRacks(racks);
    notifyListeners();
  }

  void deleteRack(String rackCode) {
    racks.removeWhere((r) => r.rackCode.toUpperCase() == rackCode.toUpperCase());
    LocalStorageService.saveRacks(racks);
    notifyListeners();
  }

  Customer addCustomer({
    required String fullName,
    required String phone,
    String company = '',
    String address = '',
    String email = '',
    String city = '',
    String notes = '',
  }) {
    final c = Customer(
      id:        'C-${(_custN++).toString().padLeft(3, "0")}',
      fullName:  fullName,
      phone:     phone,
      company:   company,
      city:      city.isNotEmpty ? city : address,
      address:   address,
      email:     email,
      notes:     notes,
      createdAt: DateTime.now(),
    );
    customers.add(c);
    LocalStorageService.saveCustomers(customers);
    InsforgeService.postCustomer(c);
    pushFullStateToCloud();
    notifyListeners();
    return c;
  }

  void updateCustomer({
    required String id,
    required String fullName,
    required String phone,
    String? company,
    String? address,
    String? email,
    String? city,
    String? notes,
    double? balanceDue,
  }) {
    final idx = customers.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final old = customers[idx];
    final updated = old.copyWith(
      fullName: fullName,
      phone: phone,
      company: company ?? old.company,
      address: address ?? old.address,
      email: email ?? old.email,
      city: city ?? (address != null && address.isNotEmpty ? address : old.city),
      notes: notes ?? old.notes,
      balanceDue: balanceDue ?? old.balanceDue,
    );
    customers[idx] = updated;
    LocalStorageService.saveCustomers(customers);
    InsforgeService.postCustomer(updated);
    pushFullStateToCloud();
    notifyListeners();
  }

  void deleteCustomer(String id) {
    customers.removeWhere((c) => c.id == id);
    LocalStorageService.saveCustomers(customers);
    InsforgeService.deleteCustomer(id);
    pushFullStateToCloud();
    notifyListeners();
  }

  MaterialItem createNewMaterial({
    required String categoryId,
    required String name,
    required String finish,
  }) {
    final m = MaterialItem(
      id:          (_matN++).toString().padLeft(4, '0'),
      name:        name,
      categoryId:  'CAT-$categoryId',
      origin:      'Unknown',
      finish:      finish,
      pricePerSqm: 100.0,
      colorFamily: categoryId,
    );
    materials.add(m);
    LocalStorageService.saveMaterials(materials);
    InsforgeService.postMaterial(m);
    notifyListeners();
    return m;
  }

  void updateSlab(String slabId, {
    double? lengthCm,
    double? widthCm,
    String? warehouseLocation,
    String? defectNotes,
    bool?   hasDefect,
  }) {
    _updateSlab(slabId, (s) => s.copyWith(
      lengthCm:          lengthCm          ?? s.lengthCm,
      widthCm:           widthCm           ?? s.widthCm,
      warehouseLocation: warehouseLocation ?? s.warehouseLocation,
      defectNotes:       defectNotes       ?? s.defectNotes,
      hasDefect:         hasDefect         ?? s.hasDefect,
      areaSqm: (lengthCm != null || widthCm != null)
          ? ((lengthCm ?? s.lengthCm) * (widthCm ?? s.widthCm)) / 10000
          : s.areaSqm,
    ));
  }

  // -- Slab status transitions -----------------------------------------------
  void _updateSlab(String slabId, Slab Function(Slab) transform) {
    final i = slabs.indexWhere((s) => s.id == slabId || s.slabNo == slabId);
    if (i == -1) return;
    final updated = transform(slabs[i]);
    slabs[i] = updated;
    LocalStorageService.saveSlabs(slabs);
    InsforgeService.updateSlabStatus(
      updated.slabNo,
      updated.status,
      reservedPrice: updated.reservedPrice,
      defectNotes: updated.defectNotes,
    );
    pushFullStateToCloud();
    notifyListeners();
  }

  void reserveSlab(String slabId, {double? price}) =>
      _updateSlab(slabId, (s) => s.copyWith(status: SlabStatus.reserved, reservedPrice: price));

  void sellSlab(String slabId) =>
      _updateSlab(slabId, (s) => s.copyWith(status: SlabStatus.sold));

  void releaseSlab(String slabId) =>
      _updateSlab(slabId, (s) => s.copyWith(status: SlabStatus.available, reservedPrice: null));

  // Mark a slab as damaged -- removes it from available/reserved pools.
  void markDamaged(String slabId, {String? defectNotes}) =>
      _updateSlab(slabId, (s) => s.copyWith(
        status: SlabStatus.damaged,
        hasDefect: true,
        defectNotes: defectNotes ?? s.defectNotes ?? 'Marked damaged by warehouse operator',
      ));

  // Restore a damaged slab back to available stock
  void restoreDamagedSlab(String slabId, {bool clearDefectNotes = false}) =>
      _updateSlab(slabId, (s) => s.copyWith(
        status: SlabStatus.available,
        hasDefect: clearDefectNotes ? false : s.hasDefect,
        defectNotes: clearDefectNotes ? null : s.defectNotes,
      ));

  // Set individual slab availability
  void setSlabAvailability(String slabId, bool isAvailable) {
    _updateSlab(slabId, (s) => s.copyWith(
      status: isAvailable ? SlabStatus.available : SlabStatus.unavailable,
    ));
  }

  // Set multiple selected slabs status (available, unavailable, damaged)
  void setMultipleSlabsStatus(List<String> slabIds, SlabStatus status, {String? defectNotes}) {
    bool changed = false;
    for (int i = 0; i < slabs.length; i++) {
      if (slabIds.contains(slabs[i].id) || slabIds.contains(slabs[i].slabNo)) {
        slabs[i] = slabs[i].copyWith(
          status: status,
          hasDefect: status == SlabStatus.damaged
              ? true
              : (status == SlabStatus.available ? false : slabs[i].hasDefect),
          defectNotes: status == SlabStatus.damaged
              ? (defectNotes ?? slabs[i].defectNotes ?? 'Marked damaged by warehouse operator')
              : slabs[i].defectNotes,
        );
        changed = true;
        InsforgeService.updateSlabStatus(
          slabs[i].slabNo,
          status,
          defectNotes: slabs[i].defectNotes,
        );
      }
    }
    if (changed) {
      LocalStorageService.saveSlabs(slabs);
      notifyListeners();
    }
  }

  // Set multiple selected slabs availability
  void setMultipleSlabsAvailability(List<String> slabIds, bool isAvailable) {
    final targetStatus = isAvailable ? SlabStatus.available : SlabStatus.unavailable;
    bool changed = false;
    for (int i = 0; i < slabs.length; i++) {
      if (slabIds.contains(slabs[i].id) || slabIds.contains(slabs[i].slabNo)) {
        slabs[i] = slabs[i].copyWith(status: targetStatus);
        changed = true;
        InsforgeService.updateSlabStatus(slabs[i].slabNo, targetStatus);
      }
    }
    if (changed) {
      LocalStorageService.saveSlabs(slabs);
      notifyListeners();
    }
  }

  // Set all slabs for a given material availability
  void setMaterialSlabsAvailability(String materialCode, bool isAvailable) {
    final targetStatus = isAvailable ? SlabStatus.available : SlabStatus.unavailable;
    bool changed = false;
    for (int i = 0; i < slabs.length; i++) {
      if (slabs[i].materialId == materialCode) {
        slabs[i] = slabs[i].copyWith(status: targetStatus);
        changed = true;
        InsforgeService.updateSlabStatus(slabs[i].slabNo, targetStatus);
      }
    }
    if (changed) {
      LocalStorageService.saveSlabs(slabs);
      notifyListeners();
    }
  }

  // -- Audits ----------------------------------------------------------------
  void updateAudit(String materialId, {
    double? physicalSqm,
    bool?   isCounted,
    double? erpIn,
    double? erpOut,
    double? erpBalanceOverride,
    double? appSqmOverride,
    String? lastCountDate,
    String? notes,
    String? materialName,
    int?    categoryCode,
  }) {
    final existing = materialAudits[materialId] ?? MaterialAuditRecord(
      materialId:  materialId,
      codeText: materialId,
      materialName: materialName ?? '',
      categoryCode: categoryCode ?? 12,
      physicalSqm: 0.0,
      isCounted:   false,
    );
    final updated = existing.copyWith(
      categoryCode: categoryCode ?? existing.categoryCode,
      physicalSqm: physicalSqm,
      isCounted:   isCounted,
      erpInSqm:    erpIn,
      erpOutSqm:   erpOut,
      erpBalanceOverride: erpBalanceOverride,
      appSqmOverride: appSqmOverride,
      lastCountDate: lastCountDate,
      notes: notes,
      materialName: materialName ?? existing.materialName,
    );
    materialAudits[materialId] = updated;
    LocalStorageService.saveAudits(materialAudits);
    InsforgeService.saveAudit(updated);
    notifyListeners();
  }

  // -- Reservations ----------------------------------------------------------
  Reservation createReservation({
    required String        customerId,
    required List<String>  slabIds,
    required DateTime      expiresAt,
    double                 depositAmount = 0,
    String?                notes,
  }) {
    final res = Reservation(
      id:            _resId(),
      customerId:    customerId,
      slabIds:       slabIds,
      reservedAt:    DateTime.now(),
      expiresAt:     expiresAt,
      status:        ReservationStatus.active,
      depositAmount: depositAmount,
      notes:         notes,
    );
    reservations.add(res);
    for (final id in slabIds) {
      reserveSlab(id);
    }
    LocalStorageService.saveReservations(reservations);
    LocalStorageService.saveSlabs(slabs);
    InsforgeService.postReservation(
      customerId: customerId,
      slabIds: slabIds,
      expiryDate: expiresAt,
      depositAmount: depositAmount,
      notes: notes,
      status: 'Active',
    );
    pushFullStateToCloud();
    notifyListeners();
    return res;
  }

  void cancelReservation(String resId) {
    final i = reservations.indexWhere((r) => r.id == resId);
    if (i == -1) return;
    final res = reservations[i];
    reservations[i] = res.copyWith(status: ReservationStatus.cancelled);
    for (final id in res.slabIds) {
      releaseSlab(id);
    }
    LocalStorageService.saveReservations(reservations);
    LocalStorageService.saveSlabs(slabs);
    InsforgeService.updateReservationStatus(res.id, 'Cancelled');
    pushFullStateToCloud();
    notifyListeners();
  }

  void updateReservation({
    required String resId,
    String? customerId,
    List<String>? slabIds,
    DateTime? expiresAt,
    String? notes,
    ReservationStatus? status,
  }) {
    final i = reservations.indexWhere((r) => r.id == resId);
    if (i == -1) return;
    final oldRes = reservations[i];

    // If slabs changed, release old ones that are no longer selected and reserve new ones
    if (slabIds != null) {
      final oldSet = oldRes.slabIds.toSet();
      final newSet = slabIds.toSet();
      final removed = oldSet.difference(newSet);
      final added = newSet.difference(oldSet);

      for (final id in removed) {
        releaseSlab(id);
      }
      for (final id in added) {
        reserveSlab(id);
      }
    }

    final newStatus = status ?? oldRes.status;
    // If status changed to cancelled, release all slabs
    if (oldRes.status != ReservationStatus.cancelled && newStatus == ReservationStatus.cancelled) {
      for (final id in (slabIds ?? oldRes.slabIds)) {
        releaseSlab(id);
      }
    }

    reservations[i] = Reservation(
      id: oldRes.id,
      customerId: customerId ?? oldRes.customerId,
      slabIds: slabIds ?? oldRes.slabIds,
      reservedAt: oldRes.reservedAt,
      expiresAt: expiresAt ?? oldRes.expiresAt,
      status: newStatus,
      depositAmount: oldRes.depositAmount,
      notes: notes ?? oldRes.notes,
    );
    LocalStorageService.saveReservations(reservations);
    LocalStorageService.saveSlabs(slabs);
    pushFullStateToCloud();
    notifyListeners();
  }

  // -- Sales -----------------------------------------------------------------
  Sale createSale({
    required String             customerId,
    required List<SaleLineItem> lineItems,
    required PaymentMethod      paymentMethod,
    double  discountPercent  = 0,
    double  amountPaid       = 0,
    bool    pickedUp         = false,
    DateTime? pickupDate,
    String? notes,
    String? fromReservationId,
  }) {
    final now = DateTime.now();
    final inv = 'INV-${now.year}-${(_saleN).toString().padLeft(4, "0")}';
    final sale = Sale(
      id:                _saleId(),
      customerId:        customerId,
      lineItems:         lineItems,
      saleDate:          now,
      status:            amountPaid >= lineItems.fold(0.0, (s, i) => s + i.lineTotal) * (1 - discountPercent / 100)
                             ? SaleStatus.paid
                             : SaleStatus.invoiced,
      paymentMethod:     paymentMethod,
      discountPercent:   discountPercent,
      amountPaid:        amountPaid,
      pickedUp:          pickedUp,
      pickupDate:        pickupDate,
      invoiceNumber:     inv,
      notes:             notes,
      fromReservationId: fromReservationId,
    );
    sales.add(sale);
    for (final item in lineItems) {
      sellSlab(item.slabId);
    }
    LocalStorageService.saveSales(sales);
    LocalStorageService.saveSlabs(slabs);
    InsforgeService.postSale(sale);
    pushFullStateToCloud();

    // Mark source reservation as converted
    if (fromReservationId != null) {
      final ri = reservations.indexWhere((r) => r.id == fromReservationId);
      if (ri != -1) {
        reservations[ri] = reservations[ri].copyWith(status: ReservationStatus.converted);
        LocalStorageService.saveReservations(reservations);
      }
    }
    notifyListeners();
    return sale;
  }

  void updateSale({
    required String saleId,
    String? customerId,
    List<SaleLineItem>? lineItems,
    DateTime? saleDate,
    SaleStatus? status,
    PaymentMethod? paymentMethod,
    double? amountPaid,
    bool? pickedUp,
    DateTime? pickupDate,
    String? notes,
  }) {
    final i = sales.indexWhere((s) => s.id == saleId);
    if (i == -1) return;
    final old = sales[i];

    // If slabs changed, handle slab states
    if (lineItems != null) {
      final oldSlabIds = old.lineItems.map((li) => li.slabId).toSet();
      final newSlabIds = lineItems.map((li) => li.slabId).toSet();
      final removed = oldSlabIds.difference(newSlabIds);
      final added = newSlabIds.difference(oldSlabIds);

      for (final id in removed) {
        releaseSlab(id);
      }
      for (final id in added) {
        sellSlab(id);
      }
    }

    sales[i] = Sale(
      id: old.id,
      customerId: customerId ?? old.customerId,
      lineItems: lineItems ?? old.lineItems,
      saleDate: saleDate ?? old.saleDate,
      status: status ?? old.status,
      paymentMethod: paymentMethod ?? old.paymentMethod,
      discountPercent: old.discountPercent,
      amountPaid: amountPaid ?? old.amountPaid,
      pickedUp: pickedUp ?? old.pickedUp,
      pickupDate: pickupDate ?? old.pickupDate,
      invoiceNumber: old.invoiceNumber,
      notes: notes ?? old.notes,
      fromReservationId: old.fromReservationId,
    );
    LocalStorageService.saveSales(sales);
    LocalStorageService.saveSlabs(slabs);
    notifyListeners();
  }

  void deleteSale(String saleId) {
    final i = sales.indexWhere((s) => s.id == saleId);
    if (i == -1) return;
    final sale = sales[i];
    // Return slabs to available status
    for (final item in sale.lineItems) {
      releaseSlab(item.slabId);
    }
    sales.removeAt(i);
    LocalStorageService.saveSales(sales);
    LocalStorageService.saveSlabs(slabs);
    notifyListeners();
  }

  // -- Returns ---------------------------------------------------------------
  ReturnItem createReturn({
    required String customerId,
    required double quantityReturnedSqm,
    required String returnReason,
    required String condition,
    String? originalSaleId,
    String? materialCode,
    String? inventoryId,
    bool restockToInventory = true,
    ReturnStatus status = ReturnStatus.completed,
    String? notes,
  }) {
    final now = DateTime.now();
    final randHex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).substring(4);
    final returnItem = ReturnItem(
      id: randHex,
      returnDate: now,
      originalSaleId: originalSaleId,
      customerId: customerId,
      materialCode: materialCode,
      inventoryId: inventoryId,
      quantityReturnedSqm: quantityReturnedSqm,
      returnReason: returnReason,
      condition: condition,
      restockToInventory: restockToInventory,
      status: status,
      notes: notes,
    );
    returns.add(returnItem);
    LocalStorageService.saveReturns(returns);
    notifyListeners();
    return returnItem;
  }

  void updateReturn({
    required String returnId,
    String? customerId,
    String? originalSaleId,
    String? materialCode,
    String? inventoryId,
    double? quantityReturnedSqm,
    String? returnReason,
    String? condition,
    bool? restockToInventory,
    ReturnStatus? status,
    String? notes,
  }) {
    final i = returns.indexWhere((r) => r.id == returnId);
    if (i == -1) return;
    final old = returns[i];

    returns[i] = old.copyWith(
      customerId: customerId,
      originalSaleId: originalSaleId,
      materialCode: materialCode,
      inventoryId: inventoryId,
      quantityReturnedSqm: quantityReturnedSqm,
      returnReason: returnReason,
      condition: condition,
      restockToInventory: restockToInventory,
      status: status,
      notes: notes,
    );
    LocalStorageService.saveReturns(returns);
    notifyListeners();
  }

  void deleteReturn(String returnId) {
    returns.removeWhere((r) => r.id == returnId);
    LocalStorageService.saveReturns(returns);
    notifyListeners();
  }

  // -- Payments --------------------------------------------------------------
  PaymentRecord addPayment({
    required String customerId,
    required double amountPaid,
    required String paymentType,
    String? relatedSaleId,
    String? relatedReservationId,
    String? notes,
  }) {
    final randHex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).substring(4);
    final payment = PaymentRecord(
      id: randHex,
      paymentDate: DateTime.now(),
      customerId: customerId,
      relatedSaleId: relatedSaleId,
      relatedReservationId: relatedReservationId,
      amountPaid: amountPaid,
      paymentType: paymentType,
      notes: notes,
    );
    payments.add(payment);
    LocalStorageService.savePayments(payments);

    // If linked to a sale, update sale's amountPaid and status
    if (relatedSaleId != null) {
      final si = sales.indexWhere((s) => s.id == relatedSaleId);
      if (si != -1) {
        final sale = sales[si];
        final newPaid = sale.amountPaid + amountPaid;
        final isFullyPaid = newPaid >= sale.total;
        sales[si] = Sale(
          id: sale.id,
          customerId: sale.customerId,
          lineItems: sale.lineItems,
          saleDate: sale.saleDate,
          status: isFullyPaid ? SaleStatus.paid : sale.status,
          paymentMethod: sale.paymentMethod,
          discountPercent: sale.discountPercent,
          amountPaid: newPaid,
          pickedUp: sale.pickedUp,
          pickupDate: sale.pickupDate,
          invoiceNumber: sale.invoiceNumber,
          notes: sale.notes,
          fromReservationId: sale.fromReservationId,
        );
        LocalStorageService.saveSales(sales);
      }
    }

    notifyListeners();
    return payment;
  }

  // Mark expired reservations -- call from initState or a timer, never build().
  void sweepExpiredReservations() {
    bool changed = false;
    for (int i = 0; i < reservations.length; i++) {
      final r = reservations[i];
      if (r.status == ReservationStatus.active && r.isExpired) {
        reservations[i] = r.copyWith(status: ReservationStatus.expired);
        changed = true;
      }
    }
    if (changed) {
      LocalStorageService.saveReservations(reservations);
      notifyListeners();
    }
  }

  /// Erases all entered data in both frontend memory and backend InsForge database.
  Future<bool> eraseAllData() async {
    isLoadingFromBackend = true;
    notifyListeners();
    try {
      final backendOk = await InsforgeService.eraseAllData();
      await LocalStorageService.clearAll();

      // Wipe all in-memory collections completely to 0
      materials.clear();
      slabs.clear();
      customers.clear();
      reservations.clear();
      sales.clear();
      returns.clear();
      payments.clear();
      materialAudits.clear();

      // Reset ID counters to 1
      _matN  = 1;
      _slabN = 1;
      _resN  = 1;
      _saleN = 1;
      _custN = 1;

      // Reset root categories to default standard tree
      categoryModels.clear();
      categoryModels.addAll(const [
        CategoryModel(categoryCode: 12, categoryName: 'Quartzite / Crystal', categoryHeader: 'Quartzite / Crystal - 12'),
        CategoryModel(categoryCode: 13, categoryName: 'Marble', categoryHeader: 'Marble - 13'),
        CategoryModel(categoryCode: 14, categoryName: 'Granite', categoryHeader: 'Granite - 14'),
        CategoryModel(categoryCode: 15, categoryName: 'Onyx', categoryHeader: 'Onyx - 15'),
        CategoryModel(categoryCode: 16, categoryName: 'Travertine', categoryHeader: 'Travertine - 16'),
        CategoryModel(categoryCode: 17, categoryName: 'Crystal / Semi Precious', categoryHeader: 'Crystal / Semi Precious - 17'),
      ]);
      categories.clear();
      categories.addAll([
        'Quartzite / Crystal', 'Marble', 'Granite', 'Onyx',
        'Travertine', 'Crystal / Semi Precious',
      ]);

      return backendOk;
    } catch (e) {
      debugPrint('Error in AppState.eraseAllData: $e');
      return false;
    } finally {
      isLoadingFromBackend = false;
      notifyListeners();
    }
  }
}

