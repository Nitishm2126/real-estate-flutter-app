import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/navigation_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/customer_service.dart';
import 'services/property_service.dart';
import 'services/theme_service.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/customer_details_screen.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── 1. Firebase (must be first – required by FCM) ──────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[MAIN] Firebase initialized.');
  } catch (e) {
    debugPrint('[MAIN] Firebase initialization failed: $e');
  }

  // ─── 2. Local Notifications (timezone + channels + permissions) ─────
  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  // ─── 3. Supabase (must be before FCM so token can be saved) ─────────
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );
  debugPrint('[MAIN] Supabase initialized.');

  // ─── 4. FCM Service (token + listeners + handlers) ──────────────────
  await FcmService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CustomerService()),
        ChangeNotifierProvider(create: (_) => PropertyService()),
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

    // Listen to LOCAL notification taps (follow-up alarm taps)
    NotificationService().selectNotificationStream.stream.listen((String? payload) {
      if (payload != null && payload.isNotEmpty) {
        _navigateToCustomer(payload);
      }
    });

    // Listen to FCM notification taps (push notification taps)
    FcmService().notificationTapStream.stream.listen((String? target) {
      if (target != null && target.isNotEmpty) {
        _navigateToCustomer(target);
      }
    });

    // Check for notifications that launched the app (local + FCM terminated)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().checkPendingNotification();
    });
  }

  void _navigateToCustomer(String customerId) {
    if (navigatorKey.currentContext == null) return;

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
      home: const _AuthGate(),
    );
  }
}

/// Root widget that decides between [LoginScreen] and [NavigationShell]
/// based on the current [AuthService] state.
///
/// Rebuilds automatically whenever the auth state changes so session
/// persistence, login, and logout are all handled in one place.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isSignedIn) {
      return const LoginScreen();
    }

    // Profile is still loading — show a branded splash
    if (auth.isLoadingProfile) {
      return const _SplashScreen();
    }

    return const NavigationShell();
  }
}

/// Minimal branded loading screen shown while the profile is fetched
/// after authentication succeeds.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppConstants.logoAsset,
              width: 64,
              height: 64,
              errorBuilder: (_, __, ___) => Icon(
                Icons.apartment_rounded,
                color: AppColors.gold,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(
              'Loading profile…',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

