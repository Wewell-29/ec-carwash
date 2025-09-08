import 'package:flutter/material.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final List<Map<String, dynamic>> products = [
    {"name": "Car Wash", "price": 300.0},
    {"name": "Interior Cleaning", "price": 500.0},
    {"name": "Waxing", "price": 800.0},
    {"name": "Tire Cleaning", "price": 200.0},
  ];

  final List<Map<String, dynamic>> cart = [];

  double get total => cart.fold(0.0, (sum, item) {
    final price = (item["price"] ?? 0.0) as double;
    final qty = (item["quantity"] ?? 0) as int;
    return sum + price * qty;
  });

  void addToCart(Map<String, dynamic> product) {
    setState(() {
      final index = cart.indexWhere((item) => item["name"] == product["name"]);
      if (index >= 0) {
        cart[index]["quantity"] = (cart[index]["quantity"] ?? 0) + 1;
      } else {
        cart.add({
          "name": product["name"],
          "price": product["price"],
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

    return Scaffold(
      body: Row(
        children: [
          /// Products Grid
          Expanded(
            flex: 2,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2, // adjusted to avoid overflow
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return InkWell(
                  onTap: () => addToCart(product),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // ✅ prevent overflow
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Icon(
                              Icons.local_car_wash,
                              size: 40,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Flexible(
                            child: Text(
                              product["name"] ?? "",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text("₱${(product["price"] ?? 0).toString()}"),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          /// Cart (only visible on wide screens)
          if (isWide) Expanded(flex: 1, child: _buildCart()),
        ],
      ),

      /// On mobile, cart is a bottom sheet
      bottomSheet: isWide ? null : _buildCart(),
    );
  }

  Widget _buildCart() {
    return Container(
      height: 300,
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
                      return ListTile(
                        title: Text(item["name"]),
                        subtitle: Text(
                          "₱${item["price"]} x ${item["quantity"] ?? 0}",
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
                  onPressed: () {
                    // TODO: Checkout logic
                  },
                  child: const Text("Checkout"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
