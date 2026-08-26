# MCP Avadi CRM - Product Requirements Document (PRD)

## 1. Product Overview
MCP Avadi CRM is a premium, enterprise-grade mobile application designed specifically for Madras City Properties, Avadi Branch. It serves as a unified platform for managing real estate leads, scheduling and tracking customer follow-ups, and delivering business analytics through a sleek, responsive interface.

## 2. Product Vision
To empower real estate agents and managers at MCP Avadi with a reliable, lightning-fast, and highly intuitive tool to maximize lead conversion and eliminate missed follow-ups through robust tracking and native reminders.

## 3. Problem Statement
Real estate agents often struggle with tracking a high volume of leads, remembering critical follow-ups, and maintaining an organized history of customer interactions. Manual tracking leads to missed opportunities, forgotten calls, and disjointed team communication.

## 4. Product Goals
- Ensure 0 missed follow-ups via a reliable Android native notification system.
- Provide instant access to customer history and interaction timelines.
- Offer actionable dashboard analytics to gauge daily workload.
- Deliver a premium, fast, and bug-free user experience.

## 5. Target Users
- **Real Estate Agents**: Primary users who input leads, schedule follow-ups, and manage day-to-day communications.
- **Branch Managers**: Users who oversee lead volume, track performance via dashboard analytics, and generate reports.

## 6. User Roles
Currently, the application operates on a unified user model (single-tenant style) authenticated securely via Supabase environment variables, treating all active users as standard CRM operators.

## 7. Core User Journey
1. Agent opens app and views the **Dashboard** for today's tasks.
2. Agent taps an upcoming follow-up to view **Customer Details**.
3. Agent uses quick actions to **Call** or **WhatsApp** the customer.
4. Agent logs a new follow-up or marks the current one completed.
5. App automatically schedules native **Notifications** for the next interaction.

## 8. Dashboard
The landing screen that provides at-a-glance analytics and tasks. It displays:
- Total Customers
- Today's Follow-ups count
- Upcoming Follow-ups count
- Recent Customers list (shimmer loading supported)
- Navigation to deep-link directly into customer details.

## 9. Customer Management
A dedicated Customers tab for viewing the complete database. It includes a scrollable list of all leads, supported by search functionality, and displays key metrics like Name, Phone, Location, and Booking Status.

## 10. Customer Details
A comprehensive drill-down screen for a single customer. It displays:
- Personal info (Name, Phone, Place)
- Lead source and Site visited
- Booking and Registration statuses
- Follow-up timeline and history
- Quick action buttons (Call/WhatsApp).

## 11. Customer Activity Timeline
A visual history (CustomerTimeline widget) on the Customer Details screen that maps out all past interactions, completed follow-ups, and notes in a chronological format.

## 12. Follow-up Management
The core workflow of the CRM. Agents can view, create, edit, and complete follow-ups. Each follow-up requires a date, time, and descriptive notes.

## 13. Multiple Follow-ups per Customer
The system supports a one-to-many relationship. A single customer can have an extensive history of multiple follow-ups, tracked incrementally (e.g., Follow-up #1, Follow-up #2), rather than overwriting a single record.

## 14. Follow-up Categories
The Follow-up List screen categorizes tasks automatically based on the current date:
- **Today**: Scheduled for the current calendar day.
- **Upcoming**: Scheduled for future dates.
- **Overdue**: Scheduled for past dates but not marked completed.
- **Completed**: Successfully resolved follow-ups.
- **All**: Unfiltered view of all follow-ups.

## 15. Follow-up Creation / Rescheduling / Completion
- **Creation**: Handled via the Add Follow-up Sheet, accepting date, time, and notes.
- **Rescheduling**: Updating an existing pending follow-up with a new future date/time.
- **Completion**: Marking a follow-up as done, which stops reminders and logs the completion timestamp.

## 16. Follow-up Quick Actions
From lists and dashboards, users can swipe or tap to quickly mark a task completed, call the lead, or open the full detail view without navigating multiple screens.

## 17. Native Phone Notifications
Critical feature: The app uses Android's local notification system to deliver exact-time alarms for scheduled follow-ups, including a 30-minute early warning. These appear on the lock screen and system tray even if the app is closed.

## 18. In-App Notifications
A dedicated Notifications Screen that acts as an inbox for recent alerts, distinct from the OS-level notifications.

## 19. Notification Bell
An interactive bell icon in the app bar that displays an unread badge counter, providing quick access to the Notifications screen.

## 20. Customer Call / WhatsApp
Integrated intent launchers that allow agents to seamlessly dial a customer's phone number or open WhatsApp/WhatsApp Business directly from the customer card.

## 21. Booking Status
A toggleable state indicating if a customer has committed to a property (Pending vs. Booked).

## 22. Registration Status
A toggleable state indicating the legal registration progress (Pending vs. Completed).

## 23. Reports
A dedicated PDF Report generation feature (accessible via a floating action button or menu). It generates a branded, printable summary of customer data and follow-ups.

## 24. Search and Filtering
A robust SearchFilterBar available on the Customers and Follow-ups screens, allowing real-time text matching against customer names, phone numbers, and locations.

## 25. Settings
A dedicated screen for app-level configurations, primarily managing Theme preferences and legal/about information.

## 26. Profile
A Profile menu accessed from the top app bar, providing quick shortcuts (e.g., to Settings) and displaying the active user/brand context.

## 27. Dark Mode / Light Mode
Full system-level and manual toggle support for Light and Dark themes. The design uses premium color palettes (e.g., deep charcoal for dark mode) to reduce eye strain.

## 28. Responsive Mobile UI
The layout is optimized for modern smartphones, ensuring scrolling, touch targets, and typography scale appropriately without overflow errors.

## 29. Bottom Navigation
A persistent Navigation Shell at the bottom of the screen with tabs for: Dashboard, Customers, Follow-ups, and More.

## 30. Hamburger Navigation Drawer
An alternative CRM Drawer accessible from the top-left, providing secondary navigation paths and branding.

## 31. Glassmorphism Navigation UI
Premium visual aesthetics applied to the Bottom Navigation bar, using frosted glass blur effects and subtle translucency.

## 32. Add Customer
A streamlined bottom sheet interface allowing agents to rapidly input new leads (Name, Phone, Location, Source) directly into the database.

## 33. Add Follow-up
A bottom sheet specifically for appending new interactions to an existing customer, seamlessly updating the timeline.

## 34. Dashboard Analytics
Real-time calculation of key metrics (Total Customers, Today's Follow-ups) displayed as large, tapable metric cards on the home screen.

## 35. Error / Empty States
Beautifully illustrated Empty State widgets that guide the user when no data is found (e.g., "No follow-ups today", "No customers match your search").

## 36. Performance Expectations
- Sub-second data retrieval from Supabase.
- Smooth 60fps scrolling on long lists.
- Instantaneous UI updates leveraging optimistic state updates where applicable.

## 37. Security Expectations
- Secure storage of Supabase Anon Keys.
- No exposed customer data in unauthenticated states.
- Read/Write policies enforced at the database level (RLS configured on backend).

## 38. Product Acceptance Criteria
- All follow-ups must trigger a native Android notification precisely at the scheduled time.
- Adding a customer must immediately reflect on the dashboard and lists.
- WhatsApp launcher must format numbers correctly and open the chat.
- UI must render without visual overflow on standard Android devices.

## 39. Future Scope
*(Planned / Not currently implemented)*
- Multi-tenant agent login and role-based access control.
- Automated SMS/Email integration.
- Advanced graphical charts for lead conversion ratios.
- Cloud-syncing of local notification preferences.
