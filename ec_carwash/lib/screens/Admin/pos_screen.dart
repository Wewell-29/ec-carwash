import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/products_data.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  String? selectedCode;
  final List<Map<String, dynamic>> cart = [];

  double get total => cart.fold(0.0, (sum, item) {
    final price = (item["price"] ?? 0) as num;
    final qty = (item["quantity"] ?? 0) as int;
    return sum + price.toDouble() * qty;
  });

  void addToCart(String code, String category, double price) {
    setState(() {
      final index = cart.indexWhere(
        (item) => item["code"] == code && item["category"] == category,
      );
      if (index >= 0) {
        cart[index]["quantity"] = (cart[index]["quantity"] ?? 0) + 1;
      } else {
        cart.add({
          "code": code,
          "category": category,
          "price": price.toDouble(), // ensure double
          "quantity": 1,
        });
      }
    });
  }

  void removeFromCart(int index) {
    setState(() {
      if (cart[index]["quantity"] > 1) {
        cart[index]["quantity"] -= 1;
      } else {
        cart.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final codes = productsData.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Point of Sale (POS)"),
        centerTitle: true,
      ),
      body: Row(
        children: [
          /// Product Codes Grid
          Expanded(
            flex: 2,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: codes.length,
              itemBuilder: (context, index) {
                final code = codes[index];
                final product = productsData[code]!;

                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedCode = code;
                    });
                  },
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: selectedCode == code
                        ? Colors.blue.shade100
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            code,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product["name"],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          /// Product Details + Cart (side panel on wide screen)
          if (isWide)
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Expanded(
                    child: selectedCode == null
                        ? const Center(
                            child: Text(
                              "Select a product code to view details",
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : _buildProductDetails(selectedCode!),
                  ),
                  _buildCart(),
                ],
              ),
            ),
        ],
      ),

      /// On mobile, show details as a bottom sheet
      bottomSheet: isWide || selectedCode == null
          ? null
          : _buildBottomSheet(selectedCode!),
    );
  }

  Widget _buildProductDetails(String code) {
    final product = productsData[code]!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Text(
            product["name"],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text("Code: $code", style: TextStyle(color: Colors.grey.shade700)),
          const Divider(),

          /// Prices list with Add button
          Expanded(
            child: ListView(
              children: (product["prices"] as Map<String, dynamic>).entries
                  .map(
                    (entry) => ListTile(
                      title: Text(entry.key),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "₱${entry.value}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => addToCart(
                              code,
                              entry.key,
                              (entry.value as num).toDouble(),
                            ),
                            child: const Text("Add"),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(String code) {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Expanded(child: _buildProductDetails(code)),
          _buildCart(),
        ],
      ),
    );
  }

  Widget _buildCart() {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.5, // half screen height
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          const ListTile(
            title: Text("Cart", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text("No items in cart"))
                : ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final price = (item["price"] as num).toDouble();
                      final qty = (item["quantity"] ?? 0) as int;
                      final subtotal = price * qty;

                      return ListTile(
                        title: Text("${item["code"]} - ${item["category"]}"),
                        subtitle: Text(
                          "₱${price.toStringAsFixed(2)} x $qty = ₱${subtotal.toStringAsFixed(2)}",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => removeFromCart(index),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total: ₱${total.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                ElevatedButton(
                  onPressed: cart.isEmpty ? null : () => _showCartSummary(),
                  child: const Text("Checkout"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCartSummary() {
    final cashController = TextEditingController();
    double change = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Summary Cart"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // List of services
                    ...cart.map((item) {
                      final price = (item["price"] as num).toDouble();
                      final qty = (item["quantity"] ?? 0) as int;
                      final subtotal = price * qty;
                      return ListTile(
                        dense: true,
                        title: Text("${item["code"]} - ${item["category"]}"),
                        subtitle: Text(
                          "₱${price.toStringAsFixed(2)} x $qty = ₱${subtotal.toStringAsFixed(2)}",
                        ),
                      );
                    }),
                    const Divider(),

                    // Totals
                    Text(
                      "Total: ₱${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cash input
                    TextField(
                      controller: cashController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Cash",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final cash = double.tryParse(val) ?? 0;
                        setState(() {
                          change = cash - total;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    Text(
                      "Change: ₱${change.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                  onPressed: (change < 0)
                      ? null // disable if change is negative
                      : () {
                          Navigator.pop(context); // close summary
                          _showReceipt(
                            cash: double.tryParse(cashController.text) ?? 0,
                            change: change,
                          );
                        },
                  child: const Text("Payment"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReceipt({required double cash, required double change}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Receipt"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...cart.map((item) {
                  final price = (item["price"] as num).toDouble();
                  final qty = (item["quantity"] ?? 0) as int;
                  final subtotal = price * qty;
                  return Text(
                    "${item["code"]} - ${item["category"]}: ₱${subtotal.toStringAsFixed(2)}",
                  );
                }),
                const Divider(),
                Text("Total: ₱${total.toStringAsFixed(2)}"),
                Text("Cash: ₱${cash.toStringAsFixed(2)}"),
                Text("Change: ₱${change.toStringAsFixed(2)}"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () async {
                final pdf = pw.Document();

                // ✅ Load embedded fonts
                final robotoRegular = pw.Font.ttf(
                  await rootBundle.load("Roboto-Regular.ttf"),
                );
                final robotoBold = pw.Font.ttf(
                  await rootBundle.load("Roboto-Bold.ttf"),
                );

                pdf.addPage(
                  pw.Page(
                    build: (pw.Context context) {
                      return pw.DefaultTextStyle(
                        style: pw.TextStyle(font: robotoRegular, fontSize: 12),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              "Carwash Receipt",
                              style: pw.TextStyle(
                                font: robotoBold,
                                fontSize: 20,
                              ),
                            ),
                            pw.SizedBox(height: 10),

                            // 🧾 Table for items
                            pw.Table(
                              border: pw.TableBorder.all(width: 0.5),
                              columnWidths: {
                                0: const pw.FlexColumnWidth(2), // Service
                                1: const pw.FlexColumnWidth(1), // Qty
                                2: const pw.FlexColumnWidth(1), // Price
                                3: const pw.FlexColumnWidth(1.5), // Subtotal
                              },
                              children: [
                                // Header row
                                pw.TableRow(
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.grey300,
                                  ),
                                  children: [
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(4),
                                      child: pw.Text(
                                        "Service",
                                        style: pw.TextStyle(
                                          font: robotoBold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(4),
                                      child: pw.Text(
                                        "Qty",
                                        style: pw.TextStyle(
                                          font: robotoBold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(4),
                                      child: pw.Text(
                                        "Price",
                                        style: pw.TextStyle(
                                          font: robotoBold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(4),
                                      child: pw.Text(
                                        "Subtotal",
                                        style: pw.TextStyle(
                                          font: robotoBold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Item rows
                                ...cart.map((item) {
                                  final price = (item["price"] as num)
                                      .toDouble();
                                  final qty = (item["quantity"] ?? 0) as int;
                                  final subtotal = price * qty;

                                  return pw.TableRow(
                                    children: [
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(
                                          "${item["code"]} - ${item["category"]}",
                                        ),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text("$qty"),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(
                                          "₱${price.toStringAsFixed(2)}",
                                        ),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(
                                          "₱${subtotal.toStringAsFixed(2)}",
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),

                            pw.SizedBox(height: 12),

                            // Totals
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.end,
                              children: [
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text(
                                      "Total: ₱${total.toStringAsFixed(2)}",
                                      style: pw.TextStyle(font: robotoBold),
                                    ),
                                    pw.Text(
                                      "Cash: ₱${cash.toStringAsFixed(2)}",
                                    ),
                                    pw.Text(
                                      "Change: ₱${change.toStringAsFixed(2)}",
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            pw.SizedBox(height: 20),
                            pw.Text(
                              "Thank you for your payment!",
                              style: pw.TextStyle(
                                font: robotoRegular,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );

                // Save/share PDF
                await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: "receipt.pdf",
                );

                setState(() {
                  cart.clear();
                });

                Navigator.pop(context);
              },
              child: const Text("Print as PDF"),
            ),
          ],
        );
      },
    );
  }
}
