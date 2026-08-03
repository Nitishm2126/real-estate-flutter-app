import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/customer.dart';
import '../utils/constants.dart';

/// HTTP service for Google Apps Script API.
/// The Google Sheet has NO ID column — all operations use field matching.
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// GET all customers from the sheet.
  Future<List<Customer>> fetchAll() async {
    final uri = Uri.parse(AppConstants.appsScriptApiUrl);

    try {
      print('--- FETCH ALL ---');
      print('URL: $uri');

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 30));

      print('Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw ApiException('fetchAll failed (${response.statusCode})');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded == null) return [];

      // Handle both formats: plain array or {status, data} object
      List<dynamic> rows = [];
      if (decoded is List) {
        rows = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        rows = decoded['data'] as List<dynamic>;
      }

      return rows
          .cast<Map<String, dynamic>>()
          .map(Customer.fromSheetJson)
          .toList();
    } catch (e, st) {
      print('fetchAll ERROR: $e');
      print('Stack: $st');
      rethrow;
    }
  }

  /// CREATE a new customer row.
  Future<void> createRow(Customer customer) async {
    final payload = <String, dynamic>{
      'action': 'create',
      ...customer.toSheetJson(),
    };

    print('--- CREATE ---');
    print('Name: ${customer.customerName}');
    print('Phone: ${customer.phoneNumber}');

    await _post(payload, 'createRow');
  }

  /// UPDATE an existing customer row.
  /// [originalCustomer] = the customer BEFORE editing (used for row matching).
  /// [customer] = the new values to write.
  Future<void> updateRow(Customer customer, {required Customer originalCustomer}) async {
    final payload = <String, dynamic>{
      'action': 'update',
      // New values
      ...customer.toSheetJson(),
      // Original values for row matching (pre-edit)
      'originalCustomerName': originalCustomer.customerName,
      'originalPhoneNumber':  originalCustomer.phoneNumber,
      'originalPlace':        originalCustomer.place,
      'originalLeadGivenBy':  originalCustomer.leadGivenBy,
      'originalDate':         originalCustomer.dateForApi,
    };

    print('--- UPDATE ---');
    print('Original: ${originalCustomer.customerName} / ${originalCustomer.phoneNumber}');
    print('New: ${customer.customerName} / ${customer.phoneNumber}');

    await _post(payload, 'updateRow');
  }

  /// DELETE a customer row.
  /// Sends all identifying fields so GAS can find the exact row.
  Future<void> deleteRow(Customer customer) async {
    final payload = <String, dynamic>{
      'action': 'delete',
      'Customer Name': customer.customerName,
      'Phone Number':  customer.phoneNumber,
      'Place':         customer.place,
      'Lead Given by': customer.leadGivenBy,
      'Date':          customer.dateForApi,
    };

    print('DELETE REQUEST');
    print('Payload: ${jsonEncode(payload)}');

    await _post(payload, 'deleteRow');
  }

  /// Common POST handler with proper error checking.
  Future<void> _post(Map<String, dynamic> payload, String operation) async {
    final uri = Uri.parse(AppConstants.appsScriptApiUrl);
    final body = jsonEncode(payload);

    print('POST to: $uri');
    print('Body: $body');

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'text/plain;charset=utf-8'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    print('$operation status code: ${response.statusCode}');
    print('$operation response body: ${response.body}');

    if (response.statusCode != 200 &&
        response.statusCode != 302 &&
        response.statusCode != 201) {
      throw ApiException('$operation failed (${response.statusCode})');
    }

    // Check for GAS-level errors inside a 200 response
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final status = decoded['status']?.toString().toLowerCase();
        if (status == 'error') {
          final msg = decoded['message']?.toString() ?? 'Unknown error';
          throw ApiException('$operation: $msg');
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      // Non-JSON or array response — check if it looks like a doGet response
      // (which means POST was redirected to GET and never ran)
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          throw ApiException(
            '$operation: POST was redirected to GET. '
            'The deployed Apps Script may be outdated. '
            'Please deploy the new Code.gs.',
          );
        }
      } catch (e2) {
        if (e2 is ApiException) rethrow;
      }
    }
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}
