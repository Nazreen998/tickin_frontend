import 'package:flutter/material.dart';
import '../app_scope.dart';

class OrderUnifiedTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderUnifiedTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderUnifiedTrackingScreen> createState() => _OrderUnifiedTrackingScreenState();
}

class _OrderUnifiedTrackingScreenState extends State<OrderUnifiedTrackingScreen> {
  bool loading = false;
  List<Map<String, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final res = await scope.timelineApi.getTimeline(widget.orderId);

      dynamic raw = res["events"] ?? res["timeline"] ?? res["items"] ?? res;
      if (raw is Map) raw = raw["events"] ?? raw["timeline"] ?? [];
      final list = (raw is List ? raw : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // ✅ Sort by createdAt / at
      list.sort((a, b) {
        final atA = (a["createdAt"] ?? a["at"] ?? "").toString();
        final atB = (b["createdAt"] ?? b["at"] ?? "").toString();
        return atB.compareTo(atA);
      });

      setState(() => events = list);
    } catch (e) {
      toast("❌ Timeline load failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _s(Map e, List<String> keys) {
    for (final k in keys) {
      final v = e[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tracking ${widget.orderId}"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
              ? const Center(child: Text("No timeline events"))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: events.length,
                  itemBuilder: (_, i) {
                    final e = events[i];
                    final title = _s(e, ["event", "title", "status"]);
                    final at = _s(e, ["createdAt", "at", "time"]);
                    final by = _s(e, ["by", "createdBy"]);
                    final dist = _s(e, ["distributorName", "distributorCode"]);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.timeline),
                        title: Text(title),
                        subtitle: Text("At: $at\nBy: $by\nDistributor: $dist"),
                      ),
                    );
                  },
                ),
    );
  }
}
