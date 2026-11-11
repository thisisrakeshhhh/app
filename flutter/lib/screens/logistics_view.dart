import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/airbnb_theme.dart';

class LogisticsView extends StatefulWidget {
  final ApiService api;
  const LogisticsView({super.key, required this.api});

  @override
  State<LogisticsView> createState() => _LogisticsViewState();
}

class _LogisticsViewState extends State<LogisticsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _carCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _otpCtrl.dispose();
    _carCtrl.dispose();
    super.dispose();
  }

  void _showCarNumberDialog() {
    _carCtrl.text = widget.api.carNumber;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Update Delivery Car / Van Number', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the vehicle registration number for this delivery shift:', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: _carCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.directions_car, color: AirbnbTheme.jodhpurBlue),
                hintText: 'e.g. RJ-19-GB-4021',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              widget.api.updateCarNumber(_carCtrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Car number updated to ${widget.api.carNumber}')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbTheme.jodhpurBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Car'),
          ),
        ],
      ),
    );
  }

  void _showOtpDialog(DeliveryStop stop) {
    _otpCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.science_outlined, color: Color(0xFFF57F17)),
            SizedBox(width: 8),
            Text('[DEMO ONLY] OTP Simulation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivering to: ${stop.shopName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            Text('COD Amount: ₹${stop.codAmountRupees.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: AirbnbTheme.coral, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFECB3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFF57F17)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('[DEMO / TEST ONLY] Offline Demo Code: ${stop.serverOtp}\n(Backend SMS gateway is not connected in this client pilot)',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFF57F17))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: '6-digit OTP',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final ok = widget.api.confirmDeliveryWithOtp(stop.id, _otpCtrl.text);
              if (ok) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('[DEMO TEST] Local delivery recorded. Not verified by backend SMS gateway.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid OTP. Please check with shop owner.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Delivery'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Van / Car Logistics Summary Banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Deep navy
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_shipping, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Car: ${widget.api.carNumber}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _showCarNumberDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Change Car', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Stock in Car', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.api.totalCarBoxes} Boxes',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Capacity: 120 Cartons',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: Colors.white24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cash in Van Custody', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${widget.api.driverCashCustodyRupees.toStringAsFixed(0)}',
                          style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const Text(
                          'Driver Handover Ready',
                          style: TextStyle(color: Colors.white60, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Three Lifecycle Streams TabBar:
        // [ 1. Order Booking ] [ 2. Ready Stock (Car) ] [ 3. Order Send (Route) ]
        Container(
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AirbnbTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AirbnbTheme.dark,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AirbnbTheme.grey,
            labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            tabs: [
              Tab(text: '1. Booking (${widget.api.bookingOrders.length})'),
              Tab(text: '2. Ready Stock (${widget.api.readyStockOrders.length})'),
              Tab(text: '3. Order Send (${widget.api.orderSendOrders.length})'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // STREAM 1: ORDER BOOKING (New orders from sales rep waiting for godown picking)
              _buildBookingStream(),

              // STREAM 2: READY STOCK & CAR LOGISTICS (Stock loaded in vehicle vs Godown)
              _buildReadyStockStream(),

              // STREAM 3: ORDER SEND (Out for delivery on route + OTP confirmation)
              _buildOrderSendStream(),
            ],
          ),
        ),
      ],
    );
  }

  // STREAM 1: Order Booking
  Widget _buildBookingStream() {
    final bookings = widget.api.bookingOrders;

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.done_all, size: 48, color: AirbnbTheme.grey),
            SizedBox(height: 8),
            Text('No pending order bookings.', style: TextStyle(fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
            Text('All booked orders are picked and transferred to vehicle.', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: bookings.length,
      itemBuilder: (ctx, i) {
        final o = bookings[i];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
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
                  Text(o.shopName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('BOOKED / PENDING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('${o.orderNumber} • ${o.address}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
              const SizedBox(height: 8),
              ...o.items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• ${it.product.name} (${it.quantity} ${it.unit.shortCode})', style: const TextStyle(fontSize: 11)),
                        Text('₹${it.totalRupees.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amount: ₹${o.totalRupees.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                      Text('Payment: ${o.paymentMode} • GST Incl.', style: const TextStyle(fontSize: 10, color: Color(0xFF6C5CE7))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.api.advanceOrderStage(o.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${o.orderNumber} picked and loaded into Car ${widget.api.carNumber}!')),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('Load into Car'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.jodhpurBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // STREAM 2: Ready Stock & Dynamic Car/Godown Stock Transfer
  Widget _buildReadyStockStream() {
    final readyOrders = widget.api.readyStockOrders;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        // Live Godown vs Car Dynamic Stock Transfer Card
        Container(
          padding: const EdgeInsets.all(14),
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
                  const Text('Car Stock Loading Manager', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Car: ${widget.api.carNumber}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Transfer boxes directly between Central Godown and Delivery Car:', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
              const Divider(height: 16),
              ...widget.api.products.take(4).map((p) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text(
                              widget.api.pendingBookingPieces(p.id) > 0
                                  ? 'Godown: ${p.godownStockBoxes} Boxes (${widget.api.pendingBookingBoxes(p.id)}b booked) • Car: ${p.carStockBoxes} Boxes'
                                  : 'Godown: ${p.godownStockBoxes} Boxes • Car: ${p.carStockBoxes} Boxes',
                              style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey),
                            ),
                          ],
                        ),
                      ),
                      // Stepper: [-1 from Car] [+1 to Car]
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                            onPressed: p.carStockBoxes > 0
                                ? () async {
                                    try {
                                      await widget.api.transferStockToCar(p.id, -1);
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Transfer failed: $e')),
                                        );
                                      }
                                    }
                                  }
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.lightGrey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${p.carStockBoxes} in Car', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20, color: AirbnbTheme.success),
                            onPressed: p.godownStockBoxes > 0
                                ? () async {
                                    try {
                                      await widget.api.transferStockToCar(p.id, 1);
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Transfer failed: $e')),
                                        );
                                      }
                                    }
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text('Orders Ready in Car (${readyOrders.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            if (readyOrders.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  for (var o in readyOrders) {
                    widget.api.advanceOrderStage(o.id);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('All ready orders dispatched in Car ${widget.api.carNumber}!')),
                  );
                },
                icon: const Icon(Icons.local_shipping, size: 14),
                label: const Text('Dispatch All on Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbTheme.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        if (readyOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No orders currently sitting in Ready Stock.', style: TextStyle(color: AirbnbTheme.grey, fontSize: 12)),
            ),
          )
        else
          ...readyOrders.map((o) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AirbnbTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(o.shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('₹${o.totalRupees.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${o.orderNumber} • ${o.items.length} items loaded in Car ${o.assignedCarNumber}',
                      style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => widget.api.advanceOrderStage(o.id),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AirbnbTheme.coral),
                        foregroundColor: AirbnbTheme.coral,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      child: const Text('Send on Route', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // STREAM 3: Order Send (Out for Delivery Stops & OTP)
  Widget _buildOrderSendStream() {
    final stops = widget.api.deliveryStops;

    if (stops.isEmpty) {
      return const Center(child: Text('No orders currently out for delivery.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: stops.length,
      itemBuilder: (ctx, i) {
        final s = stops[i];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: s.isDelivered ? AirbnbTheme.success : AirbnbTheme.border,
              width: s.isDelivered ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.area, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: s.isDelivered
                          ? AirbnbTheme.success.withValues(alpha: 0.12)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s.isDelivered ? 'DELIVERED & PAID' : 'OUT ON ROUTE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: s.isDelivered ? AirbnbTheme.success : const Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(s.shopName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${s.ownerName} • ${s.phone}\n${s.address}',
                  style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, height: 1.3)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.codAmountPaise > 0
                            ? 'COD: ₹${s.codAmountRupees.toStringAsFixed(0)}'
                            : 'Credit Khata Order',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: s.codAmountPaise > 0 ? AirbnbTheme.coral : AirbnbTheme.jodhpurBlue,
                        ),
                      ),
                      Text('Vehicle: ${widget.api.carNumber}', style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                    ],
                  ),
                  if (!s.isDelivered)
                    ElevatedButton.icon(
                      onPressed: () => _showOtpDialog(s),
                      icon: const Icon(Icons.qr_code_scanner, size: 14),
                      label: const Text('Verify OTP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbTheme.coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    )
                  else
                    Row(
                      children: const [
                        Icon(Icons.check_circle, color: AirbnbTheme.success, size: 18),
                        SizedBox(width: 4),
                        Text('Cash Collected', style: TextStyle(color: AirbnbTheme.success, fontWeight: FontWeight.w700, fontSize: 11)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
