import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/navigation_shell.dart';
import 'services/customer_service.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

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
        home: const NavigationShell(),
      ),
    );
  }
}
