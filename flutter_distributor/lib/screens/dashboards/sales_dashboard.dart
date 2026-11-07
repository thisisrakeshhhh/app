import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import '../views/add_shop_sheet.dart';
import '../views/sales_route_map_view.dart';

enum SalesAnalyticsTimeframe {
  today('timeframe_today'),
  week('timeframe_week'),
  month('timeframe_month'),
  year('timeframe_year'),
  all('timeframe_all');

  final String key;
  const SalesAnalyticsTimeframe(this.key);
}

/// Sales Representative Landing Dashboard.
/// Displays today's beat overview, interactive timeframe analytics (Today, Week, Month, Year, Till Join),
/// live visit timer & stopwatch, Zomato-style route map shortcut, quick navigation actions,
/// and recent order bookings.
class SalesDashboard extends StatefulWidget {
  final ApiService api;
  final Function(int targetTab) onNavigateTab;
  final VoidCallback? onStartVisit;

  const SalesDashboard({
    super.key,
    required this.api,
    required this.onNavigateTab,
    this.onStartVisit,
  });

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> {
  SalesAnalyticsTimeframe _selectedTimeframe = SalesAnalyticsTimeframe.today;
  int _selectedStopIndex = 0;
  bool _showGoogleMaps = true;
  MapType _mapType = MapType.normal;
  GoogleMapController? _googleMapController;

  void _openAddShopSheet() async {
    final newShop = await AddShopSheet.show(
      context,
      api: widget.api,
      defaultRouteId: 'route_sardarpura_02',
    );
    if (newShop != null) {
      widget.api.addShopToTodayBeat(newShop.id);
      if (mounted) {
        final shops = widget.api.assignedRouteShops;
        final idx = shops.indexWhere((s) => s.id == newShop.id);
        setState(() {
          if (idx != -1) _selectedStopIndex = idx;
        });
      }
    }
  }

  void _showEditShopDialog(RetailerShop shop) {
    final nameCtrl = TextEditingController(text: shop.name);
    final ownerCtrl = TextEditingController(text: shop.ownerName);
    final phoneCtrl = TextEditingController(text: shop.phone);
    final addressCtrl = TextEditingController(text: shop.address);
    final areaCtrl = TextEditingController(text: shop.area.isNotEmpty ? shop.area : 'Sardarpura');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: AirbnbTheme.jodhpurBlue),
            SizedBox(width: 8),
            Text('Edit Shop Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Shop Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ownerCtrl,
                decoration: const InputDecoration(labelText: 'Owner / Prop Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address (SCO / Gali / Plot)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: areaCtrl,
                decoration: const InputDecoration(labelText: 'Area (Sardarpura / Nai Sadak)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              await widget.api.updateRetailerDetails(
                shopId: shop.id,
                name: newName,
                ownerName: ownerCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                area: areaCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: AirbnbTheme.coral, foregroundColor: Colors.white),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showDeleteShopDialog(RetailerShop shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Manage / Delete Shop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shop: ${shop.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Choose whether to remove this shop from today\'s beat route or delete it completely:'),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.orange),
            label: const Text('Remove from Today\'s Beat', style: TextStyle(color: Colors.orange)),
            onPressed: () {
              widget.api.removeShopFromTodayBeat(shop.id);
              Navigator.pop(ctx);
              setState(() {
                _selectedStopIndex = 0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed ${shop.name} from today\'s beat')),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Delete Shop Permanently'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await widget.api.deleteRetailer(shop.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() {
                  _selectedStopIndex = 0;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted ${shop.name} permanently')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Color _getClassColor(String classType) {
    switch (classType.toUpperCase()) {
      case 'CLASS_A':
      case 'A':
        return Colors.green.shade700;
      case 'CLASS_B':
      case 'B':
        return AirbnbTheme.jodhpurBlue;
      case 'CLASS_C':
      case 'C':
        return Colors.orange.shade800;
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final retailers = widget.api.retailers;
    final assignedShops = widget.api.assignedRouteShops;
    final visitedCount = retailers.where((r) => r.visitedToday || r.isCheckedIn).length;
    final activeShop = retailers.cast<RetailerShop?>().firstWhere(
          (r) => r?.isCheckedIn == true,
          orElse: () => null,
        );

    // Calculate base sales metrics
    final todayOrders = widget.api.orders;
    final baseCount = todayOrders.length;
    final baseTotalRupees = todayOrders.fold<double>(
      0.0,
      (sum, ord) => sum + ord.totalRupees,
    );

    // Timeframe multiplier for historical aggregation simulation
    final (orderCount, totalRevenueRupees, coverageRatio, aovRupees, strikeRate) = switch (_selectedTimeframe) {
      SalesAnalyticsTimeframe.today => (
          baseCount,
          baseTotalRupees,
          '$visitedCount / ${assignedShops.length}',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 0.0,
          assignedShops.isNotEmpty ? ((visitedCount / assignedShops.length) * 100).toInt() : 0,
        ),
      SalesAnalyticsTimeframe.week => (
          (baseCount * 5.4).round() + 18,
          (baseTotalRupees * 5.8) + 42500,
          '${(visitedCount * 4).clamp(1, 38)} / 42',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 1850.0,
          88,
        ),
      SalesAnalyticsTimeframe.month => (
          (baseCount * 22).round() + 74,
          (baseTotalRupees * 23.5) + 184000,
          '164 / 180',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 1920.0,
          91,
        ),
      SalesAnalyticsTimeframe.year => (
          (baseCount * 260).round() + 890,
          (baseTotalRupees * 270) + 2150000,
          '1,840 / 1,950',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 2050.0,
          94,
        ),
      SalesAnalyticsTimeframe.all => (
          (baseCount * 480).round() + 1620,
          (baseTotalRupees * 510) + 4320000,
          '3,420 / 3,500',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 2100.0,
          96,
        ),
    };

    final locatedShops = assignedShops.where((s) => s.latitude != null && s.longitude != null).toList();
    if (_selectedStopIndex >= assignedShops.length && assignedShops.isNotEmpty) {
      _selectedStopIndex = 0;
    }
    final selectedShop = assignedShops.isNotEmpty ? assignedShops[_selectedStopIndex] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. EMBEDDED INTERACTIVE ROUTE MAP (Directly below navbar)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AirbnbTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (_showGoogleMaps && locatedShops.isNotEmpty)
                  GoogleMap(
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                    },
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        selectedShop?.latitude ?? locatedShops.first.latitude!,
                        selectedShop?.longitude ?? locatedShops.first.longitude!,
                      ),
                      zoom: 14.5,
                    ),
                    mapType: _mapType,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: locatedShops.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final s = entry.value;
                      final isSel = s.id == selectedShop?.id;
                      final isChecked = s.isCheckedIn;
                      final letter = String.fromCharCode(65 + (idx % 26));

                      return Marker(
                        markerId: MarkerId(s.id),
                        position: LatLng(s.latitude!, s.longitude!),
                        icon: isChecked
                            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
                            : isSel
                                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
                                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                        infoWindow: InfoWindow(
                          title: '$letter. ${s.name}',
                          snippet: '${s.area} • ${s.visitedToday ? "Visited" : "Pending"}',
                        ),
                        onTap: () {
                          setState(() {
                            _selectedStopIndex = assignedShops.indexOf(s);
                          });
                        },
                      );
                    }).toSet(),
                    polylines: locatedShops.length >= 2
                        ? {
                            Polyline(
                              polylineId: const PolylineId('dashboard_route_line'),
                              points: locatedShops
                                  .map((s) => LatLng(s.latitude!, s.longitude!))
                                  .toList(),
                              color: AirbnbTheme.coral,
                              width: 4,
                            ),
                          }
                        : {},
                    onMapCreated: (ctrl) => _googleMapController = ctrl,
                  )
                else
                  GestureDetector(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: ZomatoRouteMapPainter(
                        shops: locatedShops,
                        selectedIndex: selectedShop != null ? locatedShops.indexOf(selectedShop) : -1,
                        activeShopId: activeShop?.id,
                      ),
                    ),
                  ),

                // Floating Pin Badges on Canvas (when offline sketch active)
                if (!_showGoogleMaps && locatedShops.isNotEmpty)
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      return Stack(
                        children: locatedShops.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final shop = entry.value;
                          final isSelected = shop.id == selectedShop?.id;
                          final isCheckedIn = shop.isCheckedIn;
                          final isVisited = shop.visitedToday;
                          final pos = computeShopCanvasPosition(
                            shop: shop,
                            index: idx,
                            totalCount: locatedShops.length,
                            canvasSize: Size(w, h),
                            allShops: locatedShops,
                          );
                          final letter = String.fromCharCode(65 + (idx % 26));

                          return Positioned(
                            left: pos.dx - 20,
                            top: pos.dy - 24,
                            child: GestureDetector(
                              onTap: () {
                                final origIdx = assignedShops.indexOf(shop);
                                if (origIdx != -1) {
                                  setState(() => _selectedStopIndex = origIdx);
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: isSelected ? AirbnbTheme.coral : AirbnbTheme.border,
                                        width: isSelected ? 1.5 : 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      shop.name.split(' ').take(2).join(' '),
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? AirbnbTheme.coral : AirbnbTheme.dark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: isCheckedIn
                                          ? AirbnbTheme.coral
                                          : (isVisited
                                              ? AirbnbTheme.success
                                              : (isSelected ? AirbnbTheme.jodhpurBlue : const Color(0xFF475569))),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Center(
                                      child: isVisited
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                          : Text(
                                              letter,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                // Top Controls Overlay
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fullscreen Map button
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SalesRouteMapView(
                                api: widget.api,
                                onNavigateTab: widget.onNavigateTab,
                                initialShowGoogleMaps: true,
                              ),
                            ),
                          ).then((_) => setState(() {}));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AirbnbTheme.border),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                            ],
                          ),
                          child: const Icon(Icons.fullscreen_rounded, size: 16, color: AirbnbTheme.dark),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Recenter button
                      if (selectedShop?.latitude != null && selectedShop?.longitude != null)
                        InkWell(
                          onTap: () {
                            _googleMapController?.animateCamera(
                              CameraUpdate.newLatLng(
                                LatLng(selectedShop!.latitude!, selectedShop.longitude!),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AirbnbTheme.border),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                              ],
                            ),
                            child: const Icon(Icons.my_location, size: 16, color: AirbnbTheme.jodhpurBlue),
                          ),
                        ),
                      const SizedBox(width: 6),
                      // Satellite/Normal Switcher
                      InkWell(
                        onTap: () {
                          setState(() {
                            _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AirbnbTheme.border),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                            ],
                          ),
                          child: Icon(
                            _mapType == MapType.normal ? Icons.satellite_alt : Icons.map,
                            size: 16,
                            color: AirbnbTheme.dark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Map / Canvas toggle
                      InkWell(
                        onTap: () => setState(() => _showGoogleMaps = !_showGoogleMaps),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: _showGoogleMaps ? AirbnbTheme.jodhpurBlue : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AirbnbTheme.jodhpurBlue),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            _showGoogleMaps ? 'Canvas' : 'Google Map',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _showGoogleMaps ? Colors.white : AirbnbTheme.jodhpurBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Map Status / Notice label (top left)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AirbnbTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: _showGoogleMaps
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AirbnbTheme.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Google Maps • Live',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AirbnbTheme.dark,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            strings.t('route_sketch'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AirbnbTheme.grey,
                            ),
                          ),
                  ),
                ),

                // Bottom Right: "+ Add Shop" Button right on the map!
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: ElevatedButton.icon(
                    onPressed: _openAddShopSheet,
                    icon: const Icon(Icons.add_business_outlined, size: 14),
                    label: const Text('+ Add Shop', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.coral,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. TODAY'S ASSIGNED BEAT BANNER (Sardarpura & Nai Sadak Route)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D3436), Color(0xFF1E272E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
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
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.coral.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: AirbnbTheme.coral,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              strings.t('today_assigned_beat'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AirbnbTheme.coral,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${assignedShops.length} shops assigned beat',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sardarpura & Nai Sadak Route',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sequential Beat Route (A ➔ B ➔ C ➔ D) • ${assignedShops.length} Active Stops',
                  style: const TextStyle(
                    color: Color(0xFFB2BEC3),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey('continue_route_btn'),
                        onPressed: () => widget.onNavigateTab(2),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(strings.t('continue_route'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.coral,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SalesRouteMapView(api: widget.api, onNavigateTab: widget.onNavigateTab),
                          ),
                        ).then((_) => setState(() {}));
                      },
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: Text(strings.t('route_map'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stop Sequence Carousel Pills
                if (assignedShops.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: assignedShops.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final shop = entry.value;
                        final isSel = idx == _selectedStopIndex;
                        final letter = String.fromCharCode(65 + (idx % 26));

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedStopIndex = idx);
                              if (shop.latitude != null && shop.longitude != null) {
                                _googleMapController?.animateCamera(
                                  CameraUpdate.newLatLng(LatLng(shop.latitude!, shop.longitude!)),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? AirbnbTheme.coral : Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? AirbnbTheme.coral : Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    letter,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: isSel ? Colors.white : const Color(0xFFB2BEC3),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    shop.name.split(' ').take(2).join(' '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSel ? Colors.white : Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  if (shop.visitedToday) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Selected Stop In-Map Card with Full CRUD Controls
                if (selectedShop != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: selectedShop.visitedToday
                                          ? AirbnbTheme.success
                                          : (selectedShop.isCheckedIn ? AirbnbTheme.coral : AirbnbTheme.jodhpurBlue),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + (_selectedStopIndex % 26)),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedShop.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                                        ),
                                        Text(
                                          'Prop: ${selectedShop.ownerName} • ${selectedShop.phone}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 17, color: AirbnbTheme.grey),
                                  tooltip: 'Edit Shop',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showEditShopDialog(selectedShop),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 17, color: Colors.red),
                                  tooltip: 'Delete / Remove Shop',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showDeleteShopDialog(selectedShop),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getClassColor(selectedShop.classType).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    selectedShop.classType,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: _getClassColor(selectedShop.classType),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Address Details
                        Text(
                          '${selectedShop.address}, ${selectedShop.area}',
                          style: const TextStyle(fontSize: 11, color: AirbnbTheme.dark, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selectedShop.latitude != null && selectedShop.longitude != null)
                          Text(
                            'GPS: ${selectedShop.latitude!.toStringAsFixed(4)}, ${selectedShop.longitude!.toStringAsFixed(4)} (${selectedShop.area})',
                            style: const TextStyle(fontSize: 9.5, color: AirbnbTheme.grey),
                          ),
                        const SizedBox(height: 10),
                        // Action row
                        Row(
                          children: [
                            Expanded(
                              child: selectedShop.isCheckedIn
                                  ? ElevatedButton.icon(
                                      onPressed: () {
                                        widget.api.endShopVisit(selectedShop.id);
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.check_circle_outline, size: 14),
                                      label: const Text('End Visit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AirbnbTheme.dark,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () {
                                        widget.api.startShopVisit(selectedShop.id);
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.login_rounded, size: 14),
                                      label: Text(
                                        selectedShop.visitedToday ? 'Visit Again' : 'Check In',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AirbnbTheme.coral,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                widget.api.selectShop(selectedShop);
                                widget.onNavigateTab(1);
                              },
                              icon: const Icon(Icons.shopping_bag_outlined, size: 14),
                              label: const Text('Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AirbnbTheme.jodhpurBlue,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. TIMEFRAME SELECTOR CHIPS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.t('performance_on_phone'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AirbnbTheme.dark,
                ),
              ),
              Text(
                strings.t(_selectedTimeframe.key),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AirbnbTheme.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: SalesAnalyticsTimeframe.values.map((timeframe) {
                final isSelected = timeframe == _selectedTimeframe;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      strings.t(timeframe.key),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : AirbnbTheme.dark,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AirbnbTheme.dark,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AirbnbTheme.dark : AirbnbTheme.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedTimeframe = timeframe);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // 3. DYNAMIC KPI CARDS
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: strings.t('booked_orders'),
                  value: '$orderCount',
                  subtitle: '₹${totalRevenueRupees.toStringAsFixed(0)} booked',
                  icon: Icons.shopping_bag_outlined,
                  color: AirbnbTheme.coral,
                  onTap: () => widget.onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: strings.t('beat_coverage'),
                  value: coverageRatio,
                  subtitle: '$strikeRate% strike rate',
                  icon: Icons.storefront_outlined,
                  color: AirbnbTheme.jodhpurBlue,
                  onTap: () => widget.onNavigateTab(2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AirbnbTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF6C5CE7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.t('aov_title'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                            ),
                            Text('₹${aovRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF6C5CE7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AirbnbTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 16, color: AirbnbTheme.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.t('efficiency_strike'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                            ),
                            Text('$strikeRate% Visited', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AirbnbTheme.success)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // LIVE INVENTORY AVAILABILITY FOR SALES PERSON
          () {
            final totalGodownBoxes = widget.api.products.fold<int>(0, (sum, p) => sum + p.godownStockBoxes);
            final totalCarBoxes = widget.api.products.fold<int>(0, (sum, p) => sum + p.carStockBoxes);
            final activeSkuCount = widget.api.products.where((p) => p.godownStockBoxes > 0).length;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AirbnbTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                        children: const [
                          Icon(Icons.inventory_2_outlined, color: AirbnbTheme.jodhpurBlue, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Live Inventory Availability',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => widget.onNavigateTab(3),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Catalog',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right, size: 13, color: AirbnbTheme.jodhpurBlue),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => widget.onNavigateTab(3),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.warehouse_outlined, size: 13, color: Color(0xFF166534)),
                                    SizedBox(width: 4),
                                    Text('Central Godown', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$totalGodownBoxes Boxes',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF14532D)),
                                ),
                                Text(
                                  '$activeSkuCount SKUs in stock',
                                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => widget.onNavigateTab(1),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF93C5FD)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.local_shipping_outlined, size: 13, color: Color(0xFF1E40AF)),
                                    SizedBox(width: 4),
                                    Text('Delivery Truck/Van', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$totalCarBoxes Boxes',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A)),
                                ),
                                const Text(
                                  'Ready for spot delivery',
                                  style: TextStyle(fontSize: 9.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }(),

          const SizedBox(height: 16),

          // 4. ACTIVE VISIT / NEXT SHOP STATUS CARD (WITH ZOMATO ADDRESS & TIMER)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: activeShop != null ? AirbnbTheme.coral : AirbnbTheme.border,
                width: activeShop != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: activeShop != null
                            ? AirbnbTheme.coral.withValues(alpha: 0.1)
                            : AirbnbTheme.lightGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activeShop != null ? Icons.timer_outlined : Icons.place_outlined,
                        color: activeShop != null ? AirbnbTheme.coral : AirbnbTheme.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                activeShop != null ? strings.t('active_visit') : strings.t('next_scheduled_visit'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: activeShop != null ? AirbnbTheme.coral : AirbnbTheme.grey,
                                ),
                              ),
                              if (activeShop != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AirbnbTheme.coral,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    strings.t('live_timer'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activeShop != null
                                ? activeShop.name
                                : (retailers.isNotEmpty ? retailers.first.name : 'No retailers in beat'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AirbnbTheme.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            () {
                              final s = activeShop ?? (retailers.isNotEmpty ? retailers.first : null);
                              if (s == null) return 'Sardarpura, Jodhpur';
                              final prefix = [s.unitNo, s.gaaliNo].whereType<String>().join(', ');
                              if (prefix.isNotEmpty && s.address.isNotEmpty) {
                                return '$prefix • ${s.address}';
                              }
                              return s.address.isNotEmpty ? s.address : 'Address not added';
                            }(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.onNavigateTab(2); // Navigate to retailers tab
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeShop != null ? AirbnbTheme.coral : AirbnbTheme.dark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        activeShop != null ? 'View' : strings.t('check_in'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (activeShop != null) ...[
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.av_timer_rounded, size: 16, color: AirbnbTheme.coral),
                          const SizedBox(width: 4),
                          Text(
                            '${strings.t('time_spent')}: ${activeShop.activeVisitFormatted}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AirbnbTheme.coral,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => widget.onNavigateTab(1),
                        icon: const Icon(Icons.add_shopping_cart, size: 14),
                        label: const Text('Book Order for Shop', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.coral.withValues(alpha: 0.1),
                          foregroundColor: AirbnbTheme.coral,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5. QUICK ACTIONS HEADER & GRID
          const Text(
            'Quick Sales Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AirbnbTheme.dark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.add_shopping_cart,
                  label: 'New Order',
                  color: AirbnbTheme.coral,
                  onTap: () => widget.onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.map_rounded,
                  label: 'Route Map',
                  color: const Color(0xFFE67E22),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SalesRouteMapView(api: widget.api),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.store,
                  label: 'Retailers',
                  color: AirbnbTheme.jodhpurBlue,
                  onTap: () => widget.onNavigateTab(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.history,
                  label: 'My Visits',
                  color: AirbnbTheme.success,
                  onTap: () => widget.onNavigateTab(4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 6. RECENT ORDERS BOOKED TODAY
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders Booked',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AirbnbTheme.dark,
                ),
              ),
              if (todayOrders.isNotEmpty)
                GestureDetector(
                  onTap: () => widget.onNavigateTab(1),
                  child: const Text(
                    'Book Another +',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AirbnbTheme.coral,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (todayOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AirbnbTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AirbnbTheme.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 36, color: AirbnbTheme.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'No Orders Booked Yet Today',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AirbnbTheme.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select a retailer from your beat and book Kurkure & FMCG stock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => widget.onNavigateTab(1),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Book First Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbTheme.coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayOrders.take(5).length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final ord = todayOrders[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AirbnbTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AirbnbTheme.coral.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt, color: AirbnbTheme.coral, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ord.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AirbnbTheme.dark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ord.items.length} items • Order #${ord.id.substring(ord.id.length > 6 ? ord.id.length - 6 : 0)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${ord.totalRupees.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AirbnbTheme.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ord.stage.label.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AirbnbTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AirbnbTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
