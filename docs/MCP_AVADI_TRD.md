# MCP Avadi CRM - Technical Requirements Document (TRD)

## 1. Technical Overview
MCP Avadi CRM is a multi-platform application currently focused on Android, built with Flutter. It utilizes a centralized Supabase PostgreSQL backend for realtime data storage. State management is handled primarily by Provider. The app features deep OS integration for native reminders using `flutter_local_notifications`.

## 2. Technology Stack
- **Frontend Framework**: Flutter (Dart)
- **State Management**: Provider (`provider: ^6.1.2`)
- **Backend / Database**: Supabase (`supabase_flutter: ^2.5.4`), PostgreSQL
- **Notifications**: `flutter_local_notifications: ^22.3.0`, `timezone: ^0.11.1`
- **UI / Styling**: `google_fonts: ^6.2.1`, `flutter_animate: ^4.5.0`, `shimmer: ^3.0.0`
- **PDF Generation**: `pdf: ^3.11.0`, `printing: ^5.13.1`
- **External Intents**: `url_launcher: ^6.2.6`

## 3. Flutter Architecture
The application follows a standard Flutter provider-based MVC-like architecture. Business logic and backend communication are abstracted into single-responsibility Service classes, which notify listeners to trigger UI rebuilds across the Widget tree.

## 4. Project Folder Structure
- `lib/models/`: Dart data classes (e.g., `customer.dart`, `follow_up.dart`)
- `lib/services/`: Business logic, API calls, and OS integrations (e.g., `customer_service.dart`, `notification_service.dart`)
- `lib/screens/`: Full-page UI views (e.g., `dashboard_screen.dart`, `customer_details_screen.dart`)
- `lib/widgets/`: Reusable UI components (e.g., `customer_card.dart`, `add_follow_up_sheet.dart`)
- `lib/utils/`: Constants and Theme definitions.

## 5. Application Entry Point
The app initializes in `main.dart`. It sets up Flutter bindings, initializes the `NotificationService` (requesting permissions), connects to `Supabase`, and boots the `MultiProvider` enveloping the `MaterialApp` widget.

## 6. State Management
The app uses `ChangeNotifierProvider`. 
- `CustomerService`: Manages customer lists, active filters, and DB operations.
- `ThemeService`: Manages light/dark mode toggles.

## 7. Models
- `Customer`: Contains personal info, statuses, and a nested `List<FollowUp> followUpHistory`.
- `FollowUp`: Contains ID, customer ID, date, time, notes, and completion status.
- `NotificationItem`: Manages internal, in-app notification payloads.

## 8. Services
- `CustomerService`: Handles all Supabase CRUD operations for Customers and FollowUps.
- `NotificationService`: Singleton managing local Android alarms and timezone setups.
- `ThemeService`: Manages application aesthetics and user preference persistence.
- `WhatsappService`: Utility for launching external WhatsApp URLs.

## 9. Screens
- `DashboardScreen`: Overview analytics.
- `CustomersScreen`: Complete list of leads.
- `FollowUpListScreen`: Filtered task list categorized by date.
- `CustomerDetailsScreen`: Drill-down view of a single lead.
- `PdfReportScreen`: Renders and shares the generated reports.

## 10. Widgets
Modular, reusable components. Key widgets include `CustomerTimeline` for visualizing history, `SearchFilterBar` for querying data, and BottomSheets like `AddCustomerBottomSheet`.

## 11. Navigation Architecture
Handled via standard `Navigator.push/pop` and a `NavigationShell` widget acting as a persistent bottom scaffold that swaps out body pages (Dashboard, Customers, FollowUps) using a `StatefulBuilder` or `IndexedStack` approach.

## 12. Responsive Design Architecture
The UI relies on standard Flutter layout constraints (`Expanded`, `Flexible`, `MediaQuery`) without a dedicated tablet/desktop package, optimizing primarily for mobile portrait orientation.

## 13. Theme Architecture
Defined in `utils/theme.dart`. Implements `AppTheme.lightTheme` and `AppTheme.darkTheme` using Flutter's `ThemeData`, customizing `ColorScheme`, `TextTheme` (via Google Fonts), and component shapes (cards, sheets).

## 14. Light / Dark Mode
Managed by `ThemeService`, persisting user choice across sessions and reacting dynamically through `context.watch<ThemeService>()`.

## 15. Customer Data Architecture
A flat table structure in PostgreSQL mapped to the `Customer` Dart model. The model supports parsing and serializing `DateTime` and enum fields (BookingStatus, RegistrationStatus) via `toJson/fromJson`.

## 16. Customer CRUD Flow
```text
UI (AddCustomerBottomSheet)
        ↓
CustomerService.addCustomer()
        ↓
Supabase (insert into `customers` table)
        ↓
Local memory update & notifyListeners()
        ↓
UI rebuilds instantly
```

## 17. Follow-up Data Architecture
A relational model where `FollowUp` entities map to a `customer_id` foreign key.

## 18. Multiple Follow-up Architecture
Supported by a one-to-many database relationship. The `Customer` model includes `List<FollowUp> followUpHistory`, populated via a backend JOIN or explicit nested query from Supabase.

## 19. Follow-up Status Logic
Determined by the `status` string field or a non-null `completedAt` timestamp in the `FollowUp` model.

## 20. Today / Upcoming / Overdue / Completed Logic
Calculated locally in `CustomerService` or `FollowUpListScreen` by comparing `FollowUp.followUpDate` against `DateTime.now()`:
- **Today**: Date matches current date.
- **Overdue**: Date is before today and not completed.
- **Upcoming**: Date is after today.
- **Completed**: `isCompleted` is true.

## 21. Follow-up Date and Time Handling
Dates are stored as ISO8601 strings in the database. Times are stored as strings (e.g. "10:30 AM") and parsed combined with the date by the `NotificationService.parseScheduleDateTime` helper.

## 22. Timezone Handling
The application forces the `Asia/Kolkata` timezone explicitly during initialization using the `timezone` package to ensure reminders trigger correctly for Indian Standard Time regardless of device locale.

## 23. Supabase Integration
Initialized via `Supabase.initialize()`. Connects directly using the REST/Realtime SDK to perform queries, inserts, and updates directly from the client.

## 24. PostgreSQL Database Structure
- `customers` table: id (UUID), name, phone, etc.
- `customer_follow_ups` table: id (UUID), customer_id (UUID), date, time, notes, status.

## 25. Database Relationships
`customer_follow_ups` has a foreign key `customer_id` referencing `customers(id)`.

## 26. CustomerService Architecture
A singleton or provider-scoped class maintaining lists (`_allCustomers`). Features methods like `fetchCustomers()`, `addFollowUp()`, and triggers UI rebuilds. It orchestrates calls to `NotificationService` upon successful data writes.

## 27. NotificationService Architecture
A Singleton class wrapping `FlutterLocalNotificationsPlugin`. It handles channel creation, permission requests, ID generation, and the exact zoning logic for alarms.

## 28. In-App Notification Architecture
Local state (e.g., `NotificationItem` lists) tracking recent actions, completely separate from OS-level notifications.

## 29. Native Android Notification Architecture
Uses AlarmManager (exact alarms) via `flutter_local_notifications` to schedule background triggers.

## 30. flutter_local_notifications Configuration
Initialized in `NotificationService` with an `AndroidInitializationSettings` pointing to `@mipmap/launcher_icon`.

## 31. Android Notification Permissions
Handles API 33+ `POST_NOTIFICATIONS`. Handles API 31+ exact alarm permissions by gracefully requesting `requestExactAlarmsPermission()` or relying on `USE_EXACT_ALARM` in the manifest.

## 32. Android Notification Channel
Creates a high-importance channel `mcp_avadi_followup_reminders` on initialization to allow sound, vibration, and badge updates on Android 8+.

## 33. Scheduled Notification Receiver
Configured in `AndroidManifest.xml` via `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` to ensure alarms survive app kills and device reboots.

## 34. Exact Alarm Configuration
Uses `AndroidScheduleMode.exactAllowWhileIdle` to bypass Android's Doze mode and ensure the reminder fires precisely on the minute.

## 35. Notification Scheduling
```text
Follow-up Creation
        ↓
CustomerService
        ↓
Supabase (Successful DB Write)
        ↓
NotificationService.scheduleFollowUpNotification()
        ↓
Timezone conversion (Asia/Kolkata)
        ↓
Android OS AlarmManager (Exact)
```
Schedules the primary exact reminder and a secondary 30-minute early warning reminder.

## 36. Notification Cancellation
Handled via `NotificationService.cancelNotification()`. It cancels the specific ID and `ID + 1` (the early warning) whenever a follow-up is completed or deleted.

## 37. Notification Rescheduling
Handled by cancelling the existing IDs for a given follow-up and scheduling new ones with the updated time payload.

## 38. Notification IDs
Generated dynamically by hashing or parsing the first 7 characters of the UUID string into a stable 32-bit positive integer (`_generateNotificationId`).

## 39. Notification Tap / Deep Navigation
The service captures background and foreground taps via `onDidReceiveNotificationResponse`, emitting the customer ID via `selectNotificationStream`, which `main.dart` listens to in order to push a `CustomerDetailsScreen` route.

## 40. Call Integration
Utilizes `url_launcher` with the `tel:` scheme.

## 41. WhatsApp Integration
Utilizes `WhatsappService` testing the `whatsapp://` and `whatsapp_business://` schemes, falling back to `https://wa.me/` web links if the app is not installed. Handled via intent `<queries>` in the AndroidManifest.

## 42. PDF / Report Architecture
Uses the `pdf` package to construct a multi-page document layout programmatically. The `printing` package opens an OS-level preview/print dialog or saves the file locally.

## 43. Error Handling
Most network calls utilize `try/catch` blocks. Errors are surfaced to the UI via `ScaffoldMessenger` snackbars.

## 44. Loading / Empty States
- `shimmer` provides skeleton loading screens during initial network fetches.
- `EmptyState` widget displays SVG/image graphics when lists are zero-length.

## 45. Performance Requirements
Minimal widget rebuilds by scoping Provider `Consumer` widgets tightly. Timezone initialization and plugin setups are awaited only once during startup.

## 46. Security Requirements
Supabase connection secured by Anon JWT. No local storage of sensitive plaintext passwords. Access controlled via Supabase RLS.

## 47. Testing Strategy
*(Not confirmed in current implementation)* No automated unit or integration test suite is currently visible in active use.

## 48. Build / Release Process
Standard Flutter build processes (`flutter build apk`, `flutter build appbundle`). Production relies on environment variables or hardcoded constants in `constants.dart` for keys.

## 49. Current Technical Limitations
- Notification navigation while the app is in the background relies on static isolate callbacks which can be tricky to route if the Flutter engine hasn't attached a UI context.
- Single-tenant environment logic limits scaling to multiple independent branches without backend structural changes.

## 50. Future Technical Improvements
- Migrate to Riverpod or Bloc for stricter state isolation.
- Implement comprehensive unit testing for timezone parsing logic.
- Implement deep-link routing via `go_router` to improve the notification tap architecture.
