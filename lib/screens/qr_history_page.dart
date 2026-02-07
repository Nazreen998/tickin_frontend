// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../api/api.dart';

class QrHistoryPage extends StatefulWidget {
  const QrHistoryPage({super.key});

  @override
  State<QrHistoryPage> createState() => _QrHistoryPageState();
}

class _QrHistoryPageState extends State<QrHistoryPage> {
  bool loading = true;

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> qrItems = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isExpiringSoon(String expiryDate) {
    try {
      final exp = DateTime.parse(expiryDate);
      final now = DateTime.now();
      final diff = exp.difference(now).inDays;
      return diff <= 30;
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);

    try {
      // 1) products
      final prodRes = await Api.getProducts();
      final prodList = (prodRes["products"] ?? []) as List;

      products = prodList.map((e) => Map<String, dynamic>.from(e)).toList();

      // 2) qr history
      final qrRes = await Api.getQrHistory();
      final qrList = (qrRes["items"] ?? []) as List;

      qrItems = qrList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      products = [];
      qrItems = [];
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? const Center(child: Text("No products found"))
              : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];

                    final productName = (p["name"] ?? "").toString().trim();
                    if (productName.isEmpty) return const SizedBox();

                    // example: "500ML BOVONTO"
                    // We need: ml=500, itemName="BOVONTO"
                    final parts = productName.split(" ");
                    final mlText = parts.isNotEmpty ? parts.first : "";
                    final ml = int.tryParse(mlText.replaceAll("ML", "")) ?? 0;

                    final itemName = parts.skip(1).join(" ").trim();

                    // match qrItems with same itemName + ml
                    final matches = qrItems.where((it) {
                      final itName = (it["itemName"] ?? "").toString().trim().toUpperCase();
                      final itMl = (it["ml"] is num)
                          ? (it["ml"] as num).toInt()
                          : int.tryParse("${it["ml"]}") ?? 0;

                      return itName == itemName.toUpperCase() && itMl == ml;
                    }).toList();

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ Heading
                          Text(
                            productName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),

                          // ✅ QR list
                          if (matches.isEmpty)
                            Text(
                              "No QR codes",
                              style: TextStyle(color: Colors.white.withOpacity(0.6)),
                            )
                          else
                            Column(
                              children: matches.map((it) {
                                final qr = (it["qrName"] ?? "").toString();
                                final exp = (it["expiryDate"] ?? "").toString();
                                final avail = (it["availableQty"] ?? 0).toString();

                                final isRed = exp.isNotEmpty && _isExpiringSoon(exp);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isRed
                                        ? Colors.red.withOpacity(0.18)
                                        : Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isRed ? Colors.redAccent : Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          qr,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          exp.isEmpty ? "EXP: -" : "EXP: $exp",
                                        ),
                                      ),
                                      Text(
                                        "Avail: $avail",
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
