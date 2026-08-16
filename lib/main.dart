import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/navigation_shell.dart';
import 'services/customer_service.dart';
import 'services/theme_service.dart';
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CustomerService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const McpAvadiApp(),
    ),
  );
}

/// Root widget for the MCP Avadi CRM app.
class McpAvadiApp extends StatelessWidget {
  const McpAvadiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const NavigationShell(),
    );
  }
}
