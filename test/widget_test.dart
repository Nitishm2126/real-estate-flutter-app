// MCP Avadi CRM - basic smoke test.
//
// Verifies that the app starts without crashing when using
// the CustomerService provider.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mcp_avadi/main.dart';
import 'package:mcp_avadi/services/customer_service.dart';

void main() {
  testWidgets('App starts and renders DashboardScreen',
      (WidgetTester tester) async {
    // Build the root widget with the required ChangeNotifierProvider.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CustomerService(),
        child: const McpAvadiApp(),
      ),
    );

    // Allow async loading to settle.
    await tester.pumpAndSettle();

    // The app name should appear in the AppBar.
    expect(find.text('MCP Avadi'), findsOneWidget);
  });
}
