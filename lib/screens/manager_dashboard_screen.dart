import 'package:flutter/material.dart';

import 'create_order_screen.dart';
import 'slots/slot_booking_screen.dart';

// ✅ FIX: import slot confirmed orders list screen
import 'manager_orders_with_slot_screen.dart';

class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("VAGR Dashboard")),
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
    );
  }

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
