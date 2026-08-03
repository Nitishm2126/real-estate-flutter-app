import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'services/customer_service.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';

void main() {
  runApp(const McpAvadiApp());
}

/// Root widget for the MCP Avadi CRM app.
class McpAvadiApp extends StatelessWidget {
  const McpAvadiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CustomerService(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const DashboardScreen(),
      ),
    );
  }
}
