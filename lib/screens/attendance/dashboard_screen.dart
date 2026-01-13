import 'package:book_yours/screens/attendance/allowance_config_screen.dart';
import 'package:flutter/material.dart';
import 'weekly_summary_tab.dart';
import 'today_summary_tab.dart';
import 'daywise_summary_tab.dart';

class AttendanceDashboardScreen extends StatelessWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Attendance Dashboard"),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Weekly"),
              Tab(text: "Today"),
              Tab(text: "Day-wise"),
              Tab(text: "Config"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            WeeklySummaryTab(),
            TodaySummaryTab(),
            DaywiseSummaryTab(),
            AllowanceConfigTab(),
          ],
        ),
      ),
    );
  }
}
