import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    final uri = Uri.parse(AppConstants.appsScriptApiUrl.trim());

    try {
      debugLog('--- FETCH ALL ---');
      
      final response = await _requestWithRetry(
        () => _client.get(uri),
        'GET (fetchAll)',
        uri,
      );

      if (response.statusCode != 200) {
        throw ApiException('Server returned status: ${response.statusCode}');
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
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred');
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
  Future<void> updateRow(Customer customer) async {
    final payload = <String, dynamic>{
      'action': 'update',
      'ID': customer.id,
      ...customer.toSheetJson(),
    };

    debugLog('--- UPDATE ---');
    debugLog('Updating ID: ${customer.id}');
    debugLog('Payload: ${jsonEncode(payload)}');

    await _post(payload, 'updateRow');
  }

  // ─── DELETE ────────────────────────────────────────────────────
  Future<void> deleteRow(Customer customer) async {
    final payload = <String, dynamic>{
      'action': 'delete',
      'ID': customer.id,
    };

    debugLog('--- DELETE ---');
    debugLog('Deleting ID: ${customer.id}');
    debugLog('Payload: ${jsonEncode(payload)}');

    await _post(payload, 'deleteRow');
  }

  // ─── POST ──────────────────────────────────────────────────────

  Future<void> _post(
    Map<String, dynamic> payload,
    String operation,
  ) async {
    final uri = Uri.parse(AppConstants.appsScriptApiUrl.trim());
    final body = jsonEncode(payload);

    debugLog('--- POST [$operation] ---');

    final response = await _requestWithRetry(
      () => _client.post(
        uri,
        headers: {'Content-Type': 'text/plain;charset=utf-8'},
        body: body,
      ),
      'POST ($operation)',
      uri,
    );

    debugLog('[$operation] Response Body: ${response.body}');

    if (response.statusCode != 200 &&
        response.statusCode != 302 &&
        response.statusCode != 201) {
      throw ApiException('Server returned status: ${response.statusCode}');
    }

    // ── Parse the GAS JSON response ──
    Map<String, dynamic>? gasResponse;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        gasResponse = decoded;
      } else if (decoded is List) {
        // POST was redirected to GET — Apps Script not deployed correctly
        throw ApiException('Server returned an invalid format (List instead of Map). Is it a GET redirect?');
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

  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() requestFunc,
    String operation,
    Uri uri,
  ) async {
    const int maxRetries = 2; // 1 initial + 1 retry
    int attempt = 0;
    
    while (attempt < maxRetries) {
      attempt++;
      try {
        debugLog('--- HTTP REQUEST START ---');
        debugLog('[$operation] Attempt $attempt');
        debugLog('Connectivity status: Attempting network request...');
        debugLog('Request URL: $uri');
        debugLog('HTTP method: ${operation.split(' ').first}');
        
        final response = await requestFunc().timeout(const Duration(seconds: 15));
        
        debugLog('Connectivity status: Success');
        debugLog('Response Status: ${response.statusCode}');
        debugLog('Response Body: ${response.body}');
        debugLog('--- HTTP REQUEST END ---');
        
        return response;
      } catch (e) {
        debugLog('[$operation] Error on attempt $attempt: $e');
        debugLog('--- HTTP REQUEST END (WITH ERROR) ---');
        
        if (attempt >= maxRetries) {
          if (e is TimeoutException) {
            throw ApiException('Request Timed Out: $e');
          }
          if (e is SocketException) {
            throw ApiException('Network Error: $e');
          }
          if (e is ApiException) rethrow;
          
          throw ApiException('API Error: $e');
        }
      }
      
      // Small delay before retry if attempt < maxRetries
      await Future.delayed(const Duration(seconds: 1));
    }
    throw ApiException('Request failed completely');
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
