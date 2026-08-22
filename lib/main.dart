import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/navigation_shell.dart';
import 'services/customer_service.dart';
import 'services/theme_service.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/customer_details_screen.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

class McpAvadiApp extends StatefulWidget {
  const McpAvadiApp({super.key});

  @override
  State<McpAvadiApp> createState() => _McpAvadiAppState();
}

class _McpAvadiAppState extends State<McpAvadiApp> {
  @override
  void initState() {
    super.initState();
    // Listen to notification taps
    NotificationService().selectNotificationStream.stream.listen((String? payload) {
      if (payload != null && payload.isNotEmpty) {
        _navigateToCustomer(payload);
      }
    });

    // Check for notifications that launched the app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().checkPendingNotification();
    });
  }

  void _navigateToCustomer(String customerId) {
    if (navigatorKey.currentContext == null) return;
    
    // Find customer and navigate
    final service = Provider.of<CustomerService>(navigatorKey.currentContext!, listen: false);
    final customer = service.allCustomersUnfiltered.where((c) => c.id == customerId).firstOrNull;
    
    if (customer != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CustomerDetailsScreen(customer: customer),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      title: AppConstants.appName,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const NavigationShell(),
    );
  }
}
