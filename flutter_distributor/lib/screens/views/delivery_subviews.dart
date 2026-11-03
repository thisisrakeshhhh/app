import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';

/// 1. Delivery Trips View: Route manifest and stop sequence.
class DeliveryTripsView extends StatelessWidget {
  final ApiService api;
  const DeliveryTripsView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final stops = api.deliveryStops;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TRIP #TRIP-JOD-04 [Sample Trip]', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w800, fontSize: 11)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AirbnbTheme.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Text('EN ROUTE', style: TextStyle(color: AirbnbTheme.success, fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Vehicle: ${api.carNumber}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text('Route: Sardarpura, Nai Sadak & Paota FMCG Hub', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Trip Manifest & Stop Sequence', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...stops.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.isDelivered ? AirbnbTheme.success.withValues(alpha: 0.3) : AirbnbTheme.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: s.isDelivered ? AirbnbTheme.success : AirbnbTheme.dark,
                    child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${s.itemCount} items • COD: ₹${s.codAmountRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                      ],
                    ),
                  ),
                  if (s.isDelivered)
                    const Icon(Icons.check_circle, color: AirbnbTheme.success, size: 20)
                  else
                    const Icon(Icons.pending_actions, color: AirbnbTheme.grey, size: 20),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 2. Delivery Stops View: Stop-by-stop queue with OTP verification.
class DeliveryStopsView extends StatefulWidget {
  final ApiService api;
  const DeliveryStopsView({super.key, required this.api});

  @override
  State<DeliveryStopsView> createState() => _DeliveryStopsViewState();
}

class _DeliveryStopsViewState extends State<DeliveryStopsView> {
  final TextEditingController _otpCtrl = TextEditingController();

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
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
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFECB3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFF57F17)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('[DEMO / TEST ONLY] Offline Demo Code: ${stop.serverOtp}\n(Backend SMS delivery gateway is not connected in this client pilot)',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFFF57F17), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '• • • • • •',
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
              final entered = _otpCtrl.text.trim();
              final ok = widget.api.confirmDeliveryWithOtp(stop.id, entered);
              if (ok) {
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('[DEMO TEST] Local delivery recorded for ${stop.shopName}. Not verified by backend SMS gateway.'),
                    backgroundColor: AirbnbTheme.dark,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid Demo OTP! Please enter the demo code shown above.'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbTheme.dark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Verify Demo Code'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.api.deliveryStops;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: stops.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final stop = stops[idx];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: stop.isDelivered ? AirbnbTheme.success.withValues(alpha: 0.3) : AirbnbTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(stop.shopName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stop.isDelivered ? AirbnbTheme.success.withValues(alpha: 0.1) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stop.isDelivered ? 'DELIVERED ✓' : 'PENDING DELIVERY',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: stop.isDelivered ? AirbnbTheme.success : const Color(0xFFEA580C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${stop.address} • Ph: ${stop.phone}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AirbnbTheme.cardBg, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${stop.itemCount} items', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    Text('COD: ₹${stop.codAmountRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AirbnbTheme.coral)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: stop.isDelivered ? null : () => _showOtpDialog(stop),
                  icon: Icon(stop.isDelivered ? Icons.check : Icons.lock_open, size: 16),
                  label: Text(stop.isDelivered ? 'Delivery Verified & Complete' : 'Enter Delivery OTP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: stop.isDelivered ? AirbnbTheme.lightGrey : AirbnbTheme.success,
                    foregroundColor: stop.isDelivered ? AirbnbTheme.grey : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 3. Delivery Collections View: Cash collected & outstanding udhaar.
class DeliveryCollectionsView extends StatelessWidget {
  final ApiService api;
  const DeliveryCollectionsView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final stops = api.deliveryStops;
    final deliveredStops = stops.where((s) => s.isDelivered).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AirbnbTheme.dark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Van Cash in Custody', style: TextStyle(color: Color(0xFFB2BEC3), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '₹${api.driverCashCustodyRupees.toStringAsFixed(0)}',
                      style: const TextStyle(color: AirbnbTheme.success, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const Icon(Icons.payments, color: AirbnbTheme.success, size: 36),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Collection Receipts Today', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (deliveredStops.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AirbnbTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AirbnbTheme.border)),
              child: const Center(child: Text('No cash collections recorded yet. Complete OTP deliveries to collect cash.', style: TextStyle(fontSize: 11.5, color: AirbnbTheme.grey))),
            )
          else
            ...deliveredStops.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AirbnbTheme.border)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Cash on Delivery (OTP Verified)', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        ],
                      ),
                      Text('+₹${s.codAmountRupees.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AirbnbTheme.success)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

/// 4. Delivery Handover View: End-of-day van stock return & cash deposit.
class DeliveryHandoverView extends StatelessWidget {
  final ApiService api;
  const DeliveryHandoverView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AirbnbTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.assignment_turned_in_outlined, color: AirbnbTheme.dark, size: 22),
                    SizedBox(width: 8),
                    Text('End of Shift Handover (Unavailable)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Reconcile van cash custody and return remaining unsold stock to Central Godown.', style: TextStyle(fontSize: 11.5, color: AirbnbTheme.grey)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFF856404), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'UNAVAILABLE / DEMO ONLY: Persistent cash reconciliation is not implemented in this pilot. Driver cash custody remains active on device and cannot be cleared without a verified server ledger.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF856404), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Cash in Custody (Preserved):', style: TextStyle(fontSize: 13, color: AirbnbTheme.grey)),
                    Text('₹${api.driverCashCustodyRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AirbnbTheme.success)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Van Stock Remaining:', style: TextStyle(fontSize: 13, color: AirbnbTheme.grey)),
                    Text('${api.totalCarBoxes} Petis', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.jodhpurBlue)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null, // Disabled: No persistent handover reconciliation workflow exists
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Complete Shift Handover (Unavailable — Demo Only)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
