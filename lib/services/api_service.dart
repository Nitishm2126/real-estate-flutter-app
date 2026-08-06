import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/customer.dart';
import '../utils/constants.dart';

/// HTTP service for Google Apps Script API.
///
/// The Google Sheet has NO ID column — GAS uses field matching
/// (Customer Name + Phone Number + Place + Lead Given by + Date) to find rows.
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ─── FETCH ALL ─────────────────────────────────────────────────

  Future<List<Customer>> fetchAll() async {
    final uri = Uri.parse(AppConstants.appsScriptApiUrl);

    try {
      debugLog('--- FETCH ALL ---');
      debugLog('URL: $uri');

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 30));

      debugLog('Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw ApiException('fetchAll failed (${response.statusCode})');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded == null) return [];

      List<dynamic> rows = [];
      if (decoded is List) {
        rows = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        final dataField = decoded['data'];
        if (dataField is List) rows = dataField;
      }

      debugLog('Fetched ${rows.length} rows from sheet');
      return rows
          .cast<Map<String, dynamic>>()
          .map(Customer.fromSheetJson)
          .toList();
    } catch (e, st) {
      debugLog('fetchAll ERROR: $e');
      debugLog('Stack: $st');
      rethrow;
    }
  }

  // ─── CREATE ────────────────────────────────────────────────────

  Future<void> createRow(Customer customer) async {
    final payload = <String, dynamic>{
      'action': 'create',
      ...customer.toSheetJson(),
    };

    debugLog('--- CREATE ---');
    debugLog('Name: ${customer.customerName}');
    debugLog('Phone: ${customer.phoneNumber}');
    debugLog('Payload: ${jsonEncode(payload)}');

    await _post(payload, 'createRow');
  }

  // ─── UPDATE ────────────────────────────────────────────────────
  //
  // GAS handleUpdate() reads:
  //   body['originalCustomerName'] || body['Customer Name']
  //   body['originalPhoneNumber']  || body['Phone Number']
  //   body['originalPlace']        || body['Place']
  //   body['originalLeadGivenBy']  || body['Lead Given by']
  //   body['originalDate']         || body['Date']
  //
  // We MUST send the ORIGINAL values so GAS can find the existing row,
  // plus the NEW values to overwrite it with.
  Future<void> updateRow(
    Customer customer, {
    required Customer originalCustomer,
  }) async {
    final payload = <String, dynamic>{
      'action': 'update',
      // ── NEW values (what to write) ──
      ...customer.toSheetJson(),
      // ── ORIGINAL values (used by GAS to find the row) ──
      'originalCustomerName': originalCustomer.customerName,
      'originalPhoneNumber': originalCustomer.phoneNumber,
      'originalPlace': originalCustomer.place,
      'originalLeadGivenBy': originalCustomer.leadGivenBy,
      'originalDate': originalCustomer.dateForApi,
    };

    debugLog('--- UPDATE ---');
    debugLog('Original: ${originalCustomer.customerName} / ${originalCustomer.phoneNumber} / ${originalCustomer.dateForApi}');
    debugLog('New: ${customer.customerName} / ${customer.phoneNumber}');
    debugLog('Payload: ${jsonEncode(payload)}');

    await _post(payload, 'updateRow');
  }

  // ─── DELETE ────────────────────────────────────────────────────
  //
  // GAS handleDelete() reads:
  //   body['Customer Name'], body['Phone Number'],
  //   body['Place'], body['Lead Given by'], body['Date']
  //
  // These EXACT field names must be sent — GAS does NOT use an 'ID' field.
  Future<void> deleteRow(Customer customer) async {
    final payload = <String, dynamic>{
      'action': 'delete',
      'Customer Name': customer.customerName,
      'Phone Number': customer.phoneNumber,
      'Place': customer.place,
      'Lead Given by': customer.leadGivenBy,
      'Date': customer.dateForApi,
    };

    debugLog('--- DELETE ---');
    debugLog('Customer: ${customer.customerName} / ${customer.phoneNumber}');
    debugLog('Date: ${customer.dateForApi}');
    debugLog('Payload: ${jsonEncode(payload)}');

    await _post(payload, 'deleteRow');
  }

  // ─── POST ──────────────────────────────────────────────────────

  Future<void> _post(
    Map<String, dynamic> payload,
    String operation,
  ) async {
    final uri = Uri.parse(AppConstants.appsScriptApiUrl);
    final body = jsonEncode(payload);

    debugLog('POST [$operation] to: $uri');

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'text/plain;charset=utf-8'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    debugLog('[$operation] HTTP Status: ${response.statusCode}');
    debugLog('[$operation] Response: ${response.body}');

    if (response.statusCode != 200 &&
        response.statusCode != 302 &&
        response.statusCode != 201) {
      throw ApiException(
        '$operation failed: HTTP ${response.statusCode}',
      );
    }

    // ── Parse the GAS JSON response ──
    // GAS always returns JSON. If status == 'error', throw immediately.
    // A redirect to doGet (array response) means POST was swallowed.
    Map<String, dynamic>? gasResponse;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        gasResponse = decoded;
      } else if (decoded is List) {
        // POST was redirected to GET — Apps Script not deployed correctly
        throw ApiException(
          '$operation: POST was redirected to GET. '
          'The deployed Apps Script may be outdated.',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      // Non-JSON response — treat as success (some GAS deployments do this)
      debugLog('[$operation] Non-JSON response (treating as success)');
      return;
    }

    if (gasResponse != null) {
      final status = gasResponse['status']?.toString().toLowerCase();
      debugLog('[$operation] GAS status: $status');

      if (status == 'error') {
        final msg = gasResponse['message']?.toString() ?? 'Unknown error';
        throw ApiException('$operation failed: $msg');
      }

      // Log success details for debugging
      if (gasResponse.containsKey('row')) {
        debugLog('[$operation] Affected row: ${gasResponse['row']}');
      }
    }
  }

  void dispose() => _client.close();
}

/// Logs debug messages with a consistent prefix.
void debugLog(String message) {
  // ignore: avoid_print
  print('[API] $message');
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}
