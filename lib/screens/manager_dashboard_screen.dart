import 'package:book_yours/screens/attendance/dashboard_screen.dart';
import 'package:book_yours/screens/attendance_screen.dart';
import 'package:book_yours/screens/driver_orders.dart';
import 'package:book_yours/screens/my_orders_screen.dart';
import 'package:flutter/material.dart';

import 'create_order_screen.dart';
import 'slots/slot_booking_screen.dart';

// ✅ FIX: import slot confirmed orders list screen
import 'manager_orders_with_slot_screen.dart';

/// =======================================================
/// 🔥 ROLE ENUM (NEW – ACTIVE)
/// =======================================================
enum UserRole { master, manager, driver, distributor, salesOfficer }

class ManagerDashboardScreen extends StatelessWidget {
  final UserRole role;

  const ManagerDashboardScreen({
    super.key,
    this.role = UserRole.manager, // default
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("VAGR Dashboard")),

      /// ===================================================
      /// 🔥 NEW ROLE BASED DASHBOARD (ACTIVE)
      /// ===================================================
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: _roleBasedCards(context),
      ),

      /// ===================================================
      /// ❌ OLD DASHBOARD (COMMENTED – NOT DELETED)
      /// ===================================================
      /*
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _card(
            context,
            Icons.event_available,
            "Slot Booking",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SlotBookingScreen(
                    role: "MANAGER",
                    distributorCode: "MANAGER",
                    distributorName: "MANAGER",
                  ),
                ),
              );
            },
          ),

          _card(
            context,
            Icons.account_tree,
            "Orders Flow",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManagerOrdersWithSlotScreen(),
                ),
              );
            },
          ),

          _card(
            context,
            Icons.track_changes,
            "Tracking",
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Tracking open from Orders Flow screen"),
                ),
              );
            },
          ),

          _card(
            context,
            Icons.add_box_rounded,
            "Create Order",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateOrderScreen(),
                ),
              );
            },
          ),
        ],
      ),
      */
    );
  }

  /// ===================================================
  /// 🔥 ROLE SWITCH (NEW – ACTIVE)
  /// ===================================================
  List<Widget> _roleBasedCards(BuildContext context) {
    switch (role) {
      // ================= MASTER =================
      case UserRole.master:
        return [
          _card(context, Icons.today, "Today Orders", () {}),
          _card(context, Icons.dashboard, "Dashboard", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AttendanceDashboardScreen(),
              ),
            );
          }),
          _card(context, Icons.pending_actions, "Pending Orders", () {}),
          _card(context, Icons.track_changes, "Tracking", () {}),
        ];

      // ================= MANAGER =================
      case UserRole.manager:
        return [
          _card(context, Icons.add_box_rounded, "Create Order", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
            );
          }),
          _card(context, Icons.event_available, "Slot Booking", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SlotBookingScreen(
                  role: "MANAGER",
                  distributorCode: "MANAGER",
                  distributorName: "MANAGER",
                ),
              ),
            );
          }),
          _card(context, Icons.account_tree, "Order Flow", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManagerOrdersWithSlotScreen(),
              ),
            );
          }),
          _card(context, Icons.track_changes, "Tracking", () {}),
          _card(context, Icons.how_to_reg, "Attendance", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceScreen()),
            );
          }),
        ];

      // ================= DRIVER =================
      case UserRole.driver:
        return [
          _card(context, Icons.list_alt, "My Orders", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverOrdersScreen()),
            );
          }),
          _card(context, Icons.how_to_reg, "Attendance", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceScreen()),
            );
          }),
        ];

      // ================= DISTRIBUTOR =================
      case UserRole.distributor:
        return [
          _card(context, Icons.list_alt, "My Orders", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
            );
          }),
          // _card(context, Icons.event_available, "Slot Booking", () {}),
          _card(context, Icons.track_changes, "Tracking", () {}),
        ];

      // ================= SALES OFFICER =================
      case UserRole.salesOfficer:
        return [
          _card(context, Icons.add_box_rounded, "Create Order", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
            );
          }),
          _card(context, Icons.account_tree, "Order Flow", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagerOrdersWithSlotScreen()),
            );
          }),
          _card(context, Icons.track_changes, "Tracking", () {}),
        ];
    }
  }

  /// ===================================================
  /// 🔁 CARD WIDGET (UNCHANGED)
  /// ===================================================
  Widget _card(
    BuildContext ctx,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
