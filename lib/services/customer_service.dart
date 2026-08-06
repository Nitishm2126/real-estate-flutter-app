import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../utils/constants.dart';
import 'api_service.dart';

/// Sorting / filter modes available in the dashboard.
enum SortMode {
  newest,
  oldest,
  alphabetical,
  booked,
  pending,
  completedReg,
  pendingReg,
}

/// Single source of truth for customer data.
/// Talks exclusively to [ApiService] — no local storage.
class CustomerService extends ChangeNotifier {
  CustomerService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  List<Customer> _customers = [];
  String _searchQuery = '';
  SortMode _sortMode = SortMode.newest;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  Timer? _syncTimer;

  /// Local IDs of customers currently being deleted — prevents duplicate calls.
  final Set<String> _pendingDeleteIds = {};

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  SortMode get sortMode => _sortMode;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;

  // ─── Analytics ────────────────────────────────────────────────
  int totalCustomers = 0;
  int todayLeads = 0;
  int bookedCustomers = 0;
  int registrationCompleted = 0;

  void _recalculateStats() {
    final today = DateTime.now();
    final todayStr = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    totalCustomers = _customers.length;

    todayLeads = _customers.where((c) {
      if (c.date == null) return false;
      final d = c.date!.toLocal();
      final s = '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      return s == todayStr;
    }).length;

    bookedCustomers =
        _customers.where((c) => c.bookingStatus == BookingStatus.booked).length;
    registrationCompleted = _customers
        .where((c) => c.registrationStatus == RegistrationStatus.completed)
        .length;
  }

  /// Filtered + sorted list for the UI.
  List<Customer> get customers {
    Iterable<Customer> result = _customers;

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((c) =>
          c.customerName.toLowerCase().contains(q) ||
          c.phoneNumber.toLowerCase().contains(q) ||
          c.place.toLowerCase().contains(q) ||
          c.leadGivenBy.toLowerCase().contains(q));
    }

    final list = result.toList();
    switch (_sortMode) {
      case SortMode.newest:
        list.sort((a, b) =>
            (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
        break;
      case SortMode.oldest:
        list.sort((a, b) =>
            (a.date ?? DateTime(2000)).compareTo(b.date ?? DateTime(2000)));
        break;
      case SortMode.alphabetical:
        list.sort((a, b) =>
            a.customerName.toLowerCase().compareTo(b.customerName.toLowerCase()));
        break;
      case SortMode.booked:
        return list
            .where((c) => c.bookingStatus == BookingStatus.booked)
            .toList()
          ..sort((a, b) =>
              (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
      case SortMode.pending:
        return list
            .where((c) => c.bookingStatus == BookingStatus.pending)
            .toList()
          ..sort((a, b) =>
              (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
      case SortMode.completedReg:
        return list
            .where(
                (c) => c.registrationStatus == RegistrationStatus.completed)
            .toList()
          ..sort((a, b) =>
              (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
      case SortMode.pendingReg:
        return list
            .where((c) => c.registrationStatus == RegistrationStatus.pending)
            .toList()
          ..sort((a, b) =>
              (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
    }
    return list;
  }

  // ─── Lifecycle ────────────────────────────────────────────────

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchFromSheet();
    } catch (e) {
      _errorMessage = 'API Error: $e';
      debugPrint('Initial fetch failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _startAutoSync();
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      AppConstants.apiSyncInterval,
      (_) => _backgroundSync(),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _apiService.dispose();
    super.dispose();
  }

  // ─── Sync ─────────────────────────────────────────────────────

  Future<void> _fetchFromSheet() async {
    final remote = await _apiService.fetchAll();

    // Filter blank rows and exclude customers being deleted
    _customers = remote.where((c) {
      if (c.customerName.trim().isEmpty && c.phoneNumber.trim().isEmpty) {
        return false;
      }
      if (_pendingDeleteIds.contains(c.id)) return false;
      return true;
    }).toList();

    _recalculateStats();
  }

  Future<void> _backgroundSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _fetchFromSheet();
      _errorMessage = null;
    } catch (e) {
      debugPrint('Auto-sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Manual sync / pull-to-refresh.
  Future<void> syncWithApi() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchFromSheet();
    } catch (e) {
      _errorMessage = 'API Error: $e';
      debugPrint('Manual sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── ADD ──────────────────────────────────────────────────────

  Future<void> addCustomer(Customer customer) async {
    // Duplicate phone check
    if (_customers.any((c) => c.phoneNumber == customer.phoneNumber)) {
      _errorMessage = 'Customer with this phone number already exists.';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('[CS] addCustomer: ${customer.customerName}');
      await _apiService.createRow(customer);

      // Wait briefly, then reload canonical data from sheet
      await Future.delayed(const Duration(milliseconds: 700));
      await _fetchFromSheet();
    } catch (e) {
      _errorMessage = 'Failed to add customer: $e';
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── UPDATE ───────────────────────────────────────────────────

  /// Updates an existing customer.
  ///
  /// [customer] = the new (edited) values.
  /// [originalCustomer] = the pre-edit snapshot — REQUIRED so GAS can find
  ///   the exact row by matching the original field values.
  Future<void> updateCustomer(
    Customer customer, {
    required Customer originalCustomer,
  }) async {
    debugPrint('[CS] updateCustomer: ${originalCustomer.customerName} → ${customer.customerName}');
    debugPrint('[CS] Original date: ${originalCustomer.dateForApi}');
    debugPrint('[CS] New date: ${customer.dateForApi}');

    _isSyncing = true;
    notifyListeners();

    try {
      await _apiService.updateRow(customer, originalCustomer: originalCustomer);

      // Reload to confirm the update and get fresh data
      await Future.delayed(const Duration(milliseconds: 700));
      await _fetchFromSheet();
    } catch (e) {
      _errorMessage = 'Failed to update customer: $e';
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── DELETE ───────────────────────────────────────────────────

  Future<void> deleteCustomer(Customer customer) async {
    final deleteId = customer.id ?? 'unknown';

    // Prevent duplicate API calls for the same customer
    if (_pendingDeleteIds.contains(deleteId)) {
      debugPrint('[CS] Delete already in progress for ${customer.customerName}');
      return;
    }

    debugPrint('[CS] deleteCustomer START: ${customer.customerName}');
    debugPrint('[CS] Customer fields for GAS matching:');
    debugPrint('[CS]   Name:  ${customer.customerName}');
    debugPrint('[CS]   Phone: ${customer.phoneNumber}');
    debugPrint('[CS]   Place: ${customer.place}');
    debugPrint('[CS]   Lead:  ${customer.leadGivenBy}');
    debugPrint('[CS]   Date:  ${customer.dateForApi}');
    debugPrint('[CS] Count BEFORE: ${_customers.length}');

    _pendingDeleteIds.add(deleteId);
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ── Step 1: Call GAS delete API ──
      await _apiService.deleteRow(customer);
      debugPrint('[CS] GAS delete: SUCCESS');

      // ── Step 2: Remove from local cache immediately ──
      _customers.removeWhere((c) => c.id == deleteId);
      _recalculateStats();
      debugPrint('[CS] Count AFTER local remove: ${_customers.length}');
      notifyListeners(); // Instant UI update

      // ── Step 3: Reload from sheet to confirm ──
      await Future.delayed(const Duration(milliseconds: 700));
      await _fetchFromSheet();
      debugPrint('[CS] Count AFTER sheet reload: ${_customers.length}');
    } catch (e) {
      debugPrint('[CS] deleteCustomer FAILED: $e');
      _errorMessage = 'Failed to delete: $e';
      rethrow;
    } finally {
      _pendingDeleteIds.remove(deleteId);
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── Search & Sort ────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    _sortMode = mode;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
