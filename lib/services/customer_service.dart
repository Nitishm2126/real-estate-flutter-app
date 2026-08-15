import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import '../models/follow_up.dart';
import 'notification_service.dart';

/// Sorting / filter modes available in the dashboard.
enum SortMode {
  newest,
  oldest,
  alphabetical,
  booked,
  pending,
  completedReg,
  pendingReg,
  followUpsAll,
  followUpsToday,
  followUpsUpcoming,
  followUpsOverdue,
  followUpsCompleted,
}

/// Single source of truth for customer data using Supabase.
class CustomerService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Customer> _customers = [];
  String _searchQuery = '';
  SortMode _sortMode = SortMode.newest;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

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
  int followUpsTodayCount = 0;
  int overdueFollowUpsCount = 0;
  int upcomingFollowUpsCount = 0;
  int completedFollowUpsCount = 0;

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

    final todayStart = DateTime(today.year, today.month, today.day);

    followUpsTodayCount = _customers.where((c) {
      if (c.followUpDate == null || c.followUpCompleted) return false;
      final d = c.followUpDate!.toLocal();
      final s = '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      return s == todayStr;
    }).length;

    overdueFollowUpsCount = _customers.where((c) {
      if (c.followUpDate == null || c.followUpCompleted) return false;
      final d = c.followUpDate!.toLocal();
      final followUpStart = DateTime(d.year, d.month, d.day);
      return followUpStart.isBefore(todayStart);
    }).length;

    upcomingFollowUpsCount = _customers.where((c) {
      if (c.followUpDate == null || c.followUpCompleted) return false;
      final d = c.followUpDate!.toLocal();
      final followUpStart = DateTime(d.year, d.month, d.day);
      return followUpStart.isAfter(todayStart);
    }).length;

    completedFollowUpsCount =
        _customers.where((c) => c.followUpCompleted).length;
  }

  /// Helper to determine the priority of a follow-up for sorting
  int _followUpPriority(Customer c, DateTime todayStart) {
    if (c.followUpCompleted) return 4; // completed goes last
    if (c.followUpDate == null) return 5; // no follow-up goes very last

    final d = c.followUpDate!.toLocal();
    final followUpStart = DateTime(d.year, d.month, d.day);

    if (followUpStart.isBefore(todayStart)) return 1; // Overdue
    if (followUpStart.isAtSameMomentAs(todayStart)) return 2; // Today
    return 3; // Upcoming
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
        list.sort((a, b) => a.customerName
            .toLowerCase()
            .compareTo(b.customerName.toLowerCase()));
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
            .where((c) => c.registrationStatus == RegistrationStatus.completed)
            .toList()
          ..sort((a, b) =>
              (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
      case SortMode.pendingReg:
        return list
            .where((c) => c.registrationStatus == RegistrationStatus.pending)
            .toList()
          ..sort((a, b) =>
              (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));

      case SortMode.followUpsAll:
        final todayStart = DateTime.now();
        final ts = DateTime(todayStart.year, todayStart.month, todayStart.day);
        return list.where((c) => c.followUpDate != null).toList()
          ..sort((a, b) {
            final pA = _followUpPriority(a, ts);
            final pB = _followUpPriority(b, ts);
            if (pA != pB) return pA.compareTo(pB);
            return (a.followUpDate ?? DateTime(2000))
                .compareTo(b.followUpDate ?? DateTime(2000));
          });
      case SortMode.followUpsToday:
        final todayStart = DateTime.now();
        final ts = DateTime(todayStart.year, todayStart.month, todayStart.day);
        return list
            .where((c) =>
                c.followUpDate != null &&
                !c.followUpCompleted &&
                _followUpPriority(c, ts) == 2)
            .toList()
          ..sort((a, b) => (a.followUpDate ?? DateTime(2000))
              .compareTo(b.followUpDate ?? DateTime(2000)));
      case SortMode.followUpsUpcoming:
        final todayStart = DateTime.now();
        final ts = DateTime(todayStart.year, todayStart.month, todayStart.day);
        return list
            .where((c) =>
                c.followUpDate != null &&
                !c.followUpCompleted &&
                _followUpPriority(c, ts) == 3)
            .toList()
          ..sort((a, b) => (a.followUpDate ?? DateTime(2000))
              .compareTo(b.followUpDate ?? DateTime(2000)));
      case SortMode.followUpsOverdue:
        final todayStart = DateTime.now();
        final ts = DateTime(todayStart.year, todayStart.month, todayStart.day);
        return list
            .where((c) =>
                c.followUpDate != null &&
                !c.followUpCompleted &&
                _followUpPriority(c, ts) == 1)
            .toList()
          ..sort((a, b) => (a.followUpDate ?? DateTime(2000))
              .compareTo(b.followUpDate ?? DateTime(2000)));
      case SortMode.followUpsCompleted:
        return list.where((c) => c.followUpCompleted).toList()
          ..sort((a, b) => (b.followUpCompletedAt ?? DateTime(2000))
              .compareTo(a.followUpCompletedAt ?? DateTime(2000)));
    }
    return list;
  }

  // ─── Lifecycle ────────────────────────────────────────────────

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchFromSupabase();
    } catch (e) {
      _errorMessage = 'Database Error: $e';
      debugPrint('Initial fetch failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Sync ─────────────────────────────────────────────────────

  Future<void> _fetchFromSupabase() async {
    final response = await _supabase
        .from('customers')
        .select('*, customer_follow_ups(*)')
        .order('created_at', ascending: false);

    _customers =
        (response as List).map((row) => Customer.fromJson(row)).toList();

    // Filter blank rows just in case
    _customers = _customers.where((c) {
      if (c.customerName.trim().isEmpty && c.phoneNumber.trim().isEmpty) {
        return false;
      }
      return true;
    }).toList();

    _recalculateStats();
  }

  /// Manual sync / pull-to-refresh.
  Future<void> syncWithDatabase() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchFromSupabase();
    } catch (e) {
      _errorMessage = 'Database Error: $e';
      debugPrint('Manual sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── ADD ──────────────────────────────────────────────────────

  Future<Customer?> addCustomer(Customer customer) async {
    // Duplicate phone check
    if (_customers.any((c) => c.phoneNumber == customer.phoneNumber)) {
      _errorMessage = 'Customer with this phone number already exists.';
      notifyListeners();
      return null;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('[CS] addCustomer: ${customer.customerName}');
      final insertedRow = await _supabase
          .from('customers')
          .insert(customer.toJson())
          .select()
          .single();

      final newCustomer = Customer.fromJson(insertedRow);
      _customers.insert(0, newCustomer);
      _recalculateStats();
      return newCustomer;
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to add customer: ${e.message}';
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to add customer: $e';
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── UPDATE ───────────────────────────────────────────────────

  /// Updates an existing customer using the backend UUID.
  Future<void> updateCustomer(Customer customer) async {
    if (customer.id == null) {
      _errorMessage = 'Cannot update customer without a valid ID.';
      notifyListeners();
      return;
    }

    debugPrint(
        '[CS] updateCustomer: ${customer.id} → ${customer.customerName}');

    _isSyncing = true;
    notifyListeners();

    try {
      final updatedRow = await _supabase
          .from('customers')
          .update(customer.toJson())
          .eq('id', customer.id!)
          .select()
          .single();

      final updatedCustomer = Customer.fromJson(updatedRow);
      final index = _customers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        _customers[index] = updatedCustomer;
      } else {
        _customers.insert(0, updatedCustomer);
      }
      _recalculateStats();
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to update customer: ${e.message}';
      rethrow;
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
    if (customer.id == null) return;

    final deleteId = customer.id!;

    debugPrint('[CS] --- DELETE FLOW START ---');
    debugPrint('[CS] Target Customer ID: $deleteId');

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ── Step 1: Call Supabase delete API ──
      debugPrint('[CS] Sending DELETE request to Supabase...');
      await _supabase.from('customers').delete().eq('id', deleteId);
      debugPrint('[CS] Supabase response: SUCCESS');

      // ── Step 2: Remove from local cache immediately upon confirmation ──
      final customerToRemove = _customers.firstWhere((c) => c.id == deleteId);
      _customers.removeWhere((c) => c.id == deleteId);
      _recalculateStats();
      debugPrint(
          '[CS] Local list length after immediate remove: ${_customers.length}');

      // ── Step 3: Cancel all notifications for this customer ──
      try {
        await NotificationService().cancelAllForCustomer(customerToRemove);
      } catch (e) {
        debugPrint('Failed to cancel notifications for deleted customer: $e');
      }

      debugPrint('[CS] --- DELETE FLOW COMPLETE ---');
    } on PostgrestException catch (e) {
      debugPrint('[CS] deleteCustomer FAILED: ${e.message}');
      _errorMessage = 'Failed to delete: ${e.message}';
      rethrow;
    } catch (e) {
      debugPrint('[CS] deleteCustomer FAILED: $e');
      _errorMessage = 'Failed to delete: $e';
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── FOLLOW UPS ───────────────────────────────────────────────

  Future<void> addFollowUpHistory(String customerId, FollowUp followUp) async {
    _isSyncing = true;
    notifyListeners();
    try {
      final insertedRow = await _supabase
          .from('customer_follow_ups')
          .insert(followUp.toJson())
          .select()
          .single();

      final newFollowUp = FollowUp.fromJson(insertedRow);

      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        final c = _customers[index];
        final updatedHistory = List<FollowUp>.from(c.followUpHistory)
          ..add(newFollowUp);
        updatedHistory
            .sort((a, b) => b.followUpNumber.compareTo(a.followUpNumber));
        _customers[index] = c.copyWith(followUpHistory: updatedHistory);
        
        try {
          await NotificationService()
              .scheduleFollowUpNotification(_customers[index], newFollowUp);
        } catch (e) {
          debugPrint('Failed to schedule notification: $e');
        }
      }
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to save follow-up history: ${e.message}';
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to save follow-up history: $e';
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> updateFollowUpHistory(FollowUp followUp) async {
    _isSyncing = true;
    notifyListeners();
    try {
      final updatedRow = await _supabase
          .from('customer_follow_ups')
          .update(followUp.toJson())
          .eq('id', followUp.id!)
          .select()
          .single();

      final updatedFollowUp = FollowUp.fromJson(updatedRow);

      final index = _customers.indexWhere((c) => c.id == followUp.customerId);
      if (index != -1) {
        final c = _customers[index];
        final updatedHistory = List<FollowUp>.from(c.followUpHistory);
        final historyIndex =
            updatedHistory.indexWhere((h) => h.id == followUp.id);
        if (historyIndex != -1) {
          updatedHistory[historyIndex] = updatedFollowUp;
          updatedHistory
              .sort((a, b) => b.followUpNumber.compareTo(a.followUpNumber));
          _customers[index] = c.copyWith(followUpHistory: updatedHistory);
          
          try {
            await NotificationService().cancelNotification(updatedFollowUp.id!);
            if (!updatedFollowUp.isCompleted) {
              await NotificationService()
                  .scheduleFollowUpNotification(_customers[index], updatedFollowUp);
            }
          } catch (e) {
            debugPrint('Failed to reschedule notification: $e');
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to update follow-up history: $e';
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> deleteFollowUpHistory(FollowUp followUp) async {
    _isSyncing = true;
    notifyListeners();
    try {
      await _supabase
          .from('customer_follow_ups')
          .delete()
          .eq('id', followUp.id!);
      final index = _customers.indexWhere((c) => c.id == followUp.customerId);
      if (index != -1) {
        final c = _customers[index];
        final updatedHistory = List<FollowUp>.from(c.followUpHistory)
          ..removeWhere((h) => h.id == followUp.id);
        _customers[index] = c.copyWith(followUpHistory: updatedHistory);
        
        try {
          await NotificationService().cancelNotification(followUp.id!);
        } catch (e) {
          debugPrint('Failed to cancel notification: $e');
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to delete follow-up history: $e';
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollowUp(Customer customer) async {
    final isCompleted = customer.followUpCompleted;

    // Update main customer record
    final updatedCustomer = customer.copyWith(
      followUpCompleted: !isCompleted,
      followUpCompletedAt: !isCompleted ? DateTime.now() : null,
    );

    await updateCustomer(updatedCustomer);

    // Sync with history if present
    if (customer.followUpDate != null) {
      final match = customer.followUpHistory
          .where((h) =>
              h.followUpDate.year == customer.followUpDate!.year &&
              h.followUpDate.month == customer.followUpDate!.month &&
              h.followUpDate.day == customer.followUpDate!.day)
          .toList();

      if (match.isNotEmpty) {
        final h = match.first;
        final updatedH = h.copyWith(
          status: !isCompleted ? 'Completed' : 'Pending',
          completedAt: !isCompleted ? DateTime.now() : null,
        );
        await updateFollowUpHistory(updatedH);
        
        // Notification is handled inside updateFollowUpHistory, 
        // so we don't need to explicitly cancel/schedule here.
      }
    }
  }

  // ─── Search & Sort ────────────────────────────────────────────

  List<Customer> get allCustomersUnfiltered => _customers;

  int getFollowUpPriority(Customer c) {
    if (c.followUpDate == null) return -1; // No follow up
    if (c.followUpCompleted) return 3; // Completed
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fDate = DateTime(
        c.followUpDate!.year, c.followUpDate!.month, c.followUpDate!.day);
    if (fDate.isBefore(today)) return 0; // Overdue
    if (fDate.isAtSameMomentAs(today)) return 1; // Today
    return 2; // Upcoming
  }

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
