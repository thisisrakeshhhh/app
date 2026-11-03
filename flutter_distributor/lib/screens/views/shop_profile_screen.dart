import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';

class ShopProfileScreen extends StatelessWidget {
  final ApiService api;
  final RetailerShop shop;
  final VoidCallback? onRepeatOrder;

  const ShopProfileScreen({
    super.key,
    required this.api,
    required this.shop,
    this.onRepeatOrder,
  });

  Color _getClassColor(String classType) {
    switch (classType.toUpperCase()) {
      case 'A':
        return const Color(0xFF27AE60); // Green
      case 'B':
        return const Color(0xFF2980B9); // Blue
      case 'C':
        return const Color(0xFFE67E22); // Orange
      case 'D':
        return const Color(0xFFE74C3C); // Red
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final classColor = _getClassColor(shop.classType);
    final lastOrder = api.orders.cast<DistributorOrder?>().firstWhere(
          (o) => o?.shopId == shop.id,
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AirbnbTheme.dark,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AirbnbTheme.coral.withValues(alpha: 0.1),
                        child: const Icon(Icons.storefront, color: AirbnbTheme.coral, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AirbnbTheme.dark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Prop. ${shop.ownerName}',
                              style: const TextStyle(fontSize: 12, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: classColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Class ${shop.classType}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: classColor),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AirbnbTheme.lightGrey,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    shop.shopType.replaceAll('_', ' '),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.grey),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    '📍 ${shop.address}, ${shop.area}',
                    style: const TextStyle(fontSize: 12, color: AirbnbTheme.dark, height: 1.3),
                  ),

                  const SizedBox(height: 16),
                  // Action Buttons: Call, WhatsApp, Navigate
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Dialing ${shop.phone}...')),
                            );
                          },
                          icon: const Icon(Icons.call, size: 16, color: AirbnbTheme.dark),
                          label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Opening WhatsApp for ${shop.phone}...')),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF25D366)),
                          label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (shop.latitude != null && shop.longitude != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Navigating to (${shop.latitude!.toStringAsFixed(4)}, ${shop.longitude!.toStringAsFixed(4)})...')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No GPS coordinates saved for this shop')),
                              );
                            }
                          },
                          icon: const Icon(Icons.navigation_outlined, size: 16, color: AirbnbTheme.jodhpurBlue),
                          label: const Text('Directions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Financial & Credit Health Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AirbnbTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Khata & Credit Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(
                        shop.classType == 'D' ? 'Cash Only' : 'Credit Eligible',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: shop.classType == 'D' ? Colors.red : AirbnbTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Outstanding Khata', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                          const SizedBox(height: 2),
                          Text('₹${shop.outstandingRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AirbnbTheme.coral)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Credit Limit', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                          const SizedBox(height: 2),
                          Text('₹${shop.creditLimitRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Repeat Last Order Section
            if (lastOrder != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AirbnbTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Last Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text(lastOrder.orderNumber, style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...lastOrder.items.map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${it.product.name} (${it.quantity} ${it.unit.shortCode})', style: const TextStyle(fontSize: 11)),
                              Text('₹${it.totalRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        )),
                    const Divider(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onRepeatOrder ?? () {
                          // Repeat order logic: add items to cart
                          for (final it in lastOrder.items) {
                            api.addToCart(it.product, it.unit, it.quantity);
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✓ Loaded ${lastOrder.items.length} items from ${lastOrder.orderNumber} into cart')),
                          );
                        },
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text('Repeat This Order', style: TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.coral,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
