// ignore_for_file: control_flow_in_finally, unused_element, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../api/api.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool _busy = false;
  String? _lastCode;

  Future<void> _handleCode(String raw) async {
    final code = raw.trim().toUpperCase(); // A2
    if (code.isEmpty) return;

    // avoid repeated same scan spam
    if (_busy || code == _lastCode) return;

    setState(() {
      _busy = true;
      _lastCode = code;
    });

    try {
      final res = await Api.getQrItem(code);
      if (!mounted) return;

      // expecting { ok:true, data:{...} }
      final data = res["data"] as Map<String, dynamic>;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ItemSheet(qrName: code, data: data),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  // ✅ Windows manual entry UI
  Widget _manualUI() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              labelText: "Enter QR (ex: A2)",
              border: OutlineInputBorder(),
            ),
            onSubmitted: (val) => _handleCode(val),
          ),
        ),
        const Divider(),
        Expanded(
          child: Stack(
            children: [
              const Center(
                child: Text(
                  "Camera scan not available on Windows.\nUse manual QR entry above.",
                  textAlign: TextAlign.center,
                ),
              ),
              if (_busy)
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Chip(label: Text("Loading...")),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Android/iOS camera scanner UI
  Widget _cameraUI() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;

            final raw = barcodes.first.rawValue;
            if (raw == null) return;

            _handleCode(raw);
          },
        ),
        if (_busy)
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Chip(label: Text("Loading...")),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = Platform.isWindows;

    return Scaffold(
      appBar: AppBar(title: const Text("QR Scan")),
      body: isWindows ? _manualUI() : _cameraUI(),
    );
  }
}

// ====================== BOTTOM SHEET ======================

class _ItemSheet extends StatelessWidget {
  final String qrName;
  final Map<String, dynamic> data;

  const _ItemSheet({required this.qrName, required this.data});

Future<void> _showAddBatchDialog(BuildContext context, String qrName) async {
  final itemCtrl = TextEditingController();
  final mlCtrl = TextEditingController();
  final totalCtrl = TextEditingController();
  final mfgCtrl = TextEditingController();
  final expCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text("Add New Batch - $qrName"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemCtrl,
              decoration: const InputDecoration(labelText: "Item Name"),
            ),
            TextField(
              controller: mlCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "ML"),
            ),
            TextField(
              controller: totalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total Qty"),
            ),
            TextField(
              controller: mfgCtrl,
              decoration: const InputDecoration(labelText: "MFG Date (YYYY-MM-DD)"),
            ),
            TextField(
              controller: expCtrl,
              decoration: const InputDecoration(labelText: "EXP Date (YYYY-MM-DD)"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            final itemName = itemCtrl.text.trim();
            final ml = int.tryParse(mlCtrl.text.trim()) ?? 0;
            final totalQty = int.tryParse(totalCtrl.text.trim()) ?? 0;
            final mfgDate = mfgCtrl.text.trim();
            final expiryDate = expCtrl.text.trim();

            if (itemName.isEmpty || ml <= 0 || totalQty <= 0 || mfgDate.isEmpty || expiryDate.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Fill all fields correctly")),
              );
              return;
            }

            try {
              await Api.addNewBatch(
                qrName: qrName,
                totalQty: totalQty,
                itemName: itemName,
                ml: ml,
                mfgDate: mfgDate,
                expiryDate: expiryDate,
                user: "manager1",
              );

              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close bottomsheet

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("New batch added ✅")),
              );
            } catch (e) {
              print("ADD BATCH ERROR: $e"); 
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: $e")),
              );
            }
          },
          child: const Text("Submit"),
        ),
      ],
    ),
  );
}
Future<void> _showAddDialog(BuildContext context, String qrName) async {
  final itemCtrl = TextEditingController();
  final mlCtrl = TextEditingController();
  final totalCtrl = TextEditingController();
  final mfgCtrl = TextEditingController();
  final expCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text("Add New Batch - $qrName"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemCtrl,
              decoration: const InputDecoration(labelText: "Item Name"),
            ),
            TextField(
              controller: mlCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "ML"),
            ),
            TextField(
              controller: totalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total Qty"),
            ),
            TextField(
              controller: mfgCtrl,
              decoration: const InputDecoration(labelText: "MFG Date (YYYY-MM-DD)"),
            ),
            TextField(
              controller: expCtrl,
              decoration: const InputDecoration(labelText: "EXP Date (YYYY-MM-DD)"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            final itemName = itemCtrl.text.trim();
            final ml = int.tryParse(mlCtrl.text.trim()) ?? 0;
            final totalQty = int.tryParse(totalCtrl.text.trim()) ?? 0;
            final mfgDate = mfgCtrl.text.trim();
            final expiryDate = expCtrl.text.trim();

            if (itemName.isEmpty || ml <= 0 || totalQty <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Fill all fields correctly")),
              );
              return;
            }

            try {
              await Api.addNewBatch(
                qrName: qrName,
                totalQty: totalQty,
                itemName: itemName,
                ml: ml,
                mfgDate: mfgDate,
                expiryDate: expiryDate,
                user: "manager1",
              );

              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close bottomsheet

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Batch Added Successfully")),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: $e")),
              );
            }
          },
          child: const Text("Submit"),
        ),
      ],
    ),
  );
}

  Future<void> _showTakeDialog(BuildContext context, String qrName) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Take Stock - $qrName"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Taken Quantity",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(controller.text.trim()) ?? 0;
              if (qty <= 0) return;

              try {
                final res = await Api.takeStock(
                  qrName: qrName,
                  takenQty: qty,
                  user: "manager1", // later login user set pannalam
                );

                Navigator.pop(context); // close dialog
                Navigator.pop(context); // close bottomsheet (so user can rescan)

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Success: ${res["before"]} → ${res["after"]}",
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // safe reads
    String s(String k) => (data[k] ?? "").toString();
    int n(String k) =>
        (data[k] is num) ? (data[k] as num).toInt() : int.tryParse("${data[k]}") ?? 0;

    final available = n("availableQty");
    final canAddBatch = available == 0;
    return Padding(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Wrap(
        runSpacing: 10,
        children: [
          Text(
            "QR: $qrName",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          _row("Item", s("itemName")),
          _row("ML", s("ml")),
          _row("MFG", s("mfgDate")),
          _row("EXP", s("expiryDate")),
          _row("Available", available.toString()),
          const SizedBox(height: 10),

          // ✅ TAKE STOCK button
          ElevatedButton(
            onPressed: () async {
              await _showTakeDialog(context, qrName);
            },
            child: const Text("TAKE STOCK"),
          ),
          SizedBox(width: 10),

          ElevatedButton(
            onPressed: canAddBatch ? () async {
              await _showAddBatchDialog(context, qrName);
           } : null,
            child: const Text("ADD NEW BATCH"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
