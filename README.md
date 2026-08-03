# MCP Avadi

Premium CRM app for the Madras City Properties (MCP) Avadi Branch sales team, built with Flutter (Material 3).

## Getting started

```bash
flutter pub get
flutter run
```

Replace the placeholder images at `assets/logo.png` (MCP company logo) and `assets/photo.png` (T. Meenakshi Sundaram) with the real files — same filenames, same folder.

## Project structure

```
lib/
  main.dart
  models/customer.dart
  screens/dashboard_screen.dart
  screens/customer_details_screen.dart
  widgets/customer_card.dart
  widgets/add_customer_bottom_sheet.dart
  widgets/search_widget.dart
  widgets/empty_state.dart
  services/customer_service.dart
  services/api_service.dart
  utils/theme.dart
  utils/constants.dart
```

## How data flows

- `CustomerService` (a `ChangeNotifier`, wired up via `provider`) is the single
  source of truth the UI talks to. It currently persists everything to the
  device with `shared_preferences`.
- `SheetDbService` is an isolated wrapper around SheetDB's REST API. Every
  method (`fetchAll`, `createRow`, `updateRow`, `deleteRow`) is already
  written and marked with `// TODO:` where the live SheetDB URL is needed.

## Turning on SheetDB sync (when you're ready)

1. Create your Google Sheet with these exact column headers, in this order:
   `Customer Name | Phone Number | Place | Lead Given By | Site Visited | Date | Notes | Booking Status | Registration Status`
2. Create a SheetDB API from that sheet at https://sheetdb.io and copy the endpoint URL.
3. Open `lib/utils/constants.dart` and set:
   ```dart
   static const String sheetDbApiUrl = 'https://sheetdb.io/api/v1/your-id-here';
   ```
4. That's it — no other code changes needed:
   - New customers added in the app are pushed to the sheet automatically.
   - Edits and deletes in the app sync to the sheet automatically.
   - The app polls SheetDB every 30 seconds (see `sheetDbSyncInterval`) and
     merges in any rows added or changed directly in the Google Sheet — pull
     down to refresh also triggers an immediate sync.
   - Rows are matched between the app and the sheet by phone number.

## Notes

- Call and WhatsApp buttons use `url_launcher` and are fully wired — no
  placeholders. WhatsApp numbers default to the `+91` country code when a
  10-digit number is entered.
- Swipe left on a customer card to delete (with confirmation), swipe right
  to edit, long-press for the full action menu (Call / WhatsApp / Edit /
  Delete).
