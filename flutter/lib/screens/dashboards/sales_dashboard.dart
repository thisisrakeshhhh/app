import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../features/sales/routing/external_navigation_service.dart';
import '../../features/sales/routing/route_deviation_detector.dart';
import '../../features/sales/routing/route_engine_service.dart';
import '../../features/sales/routing/route_info_panel.dart';
import '../../features/sales/routing/route_models.dart';
import '../../features/sales/widgets/sales_map_markers.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import '../views/add_shop_sheet.dart';

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
  MapType _mapType = MapType.normal;
  GoogleMapController? _googleMapController;
  Timer? _stopwatchTimer;
  BitmapDescriptor? _currentLocationBlueDotIcon;
  BitmapDescriptor? _godownMarkerIcon;
  final SalesMapMarkerCache _markerCache = SalesMapMarkerCache();
  final RouteEngineService _routeEngine = RouteEngineService();
  final RouteDeviationDetector _deviationDetector = RouteDeviationDetector();
  BeatRoutePlan? _currentRoutePlan;
  bool _isRouteEngineCalculating = false;
  double? _repHeading;
  double _currentZoom = 14.5;
  bool _isMapFullscreen = false;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initCurrentLocationIcon();
    _initRealPhoneLocation();
    _computeBeatRoute();
    // 1-second live ticker for active visit stopwatch and time spent
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.api.activeVisitShopId != null) {
        setState(() {});
      }
    });
  }

  Future<void> _initRealPhoneLocation() async {
    try {
      await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {}

      if (position != null && mounted) {
        final reliableHeading = RouteDeviationDetector.extractReliableHeading(position);
        if (reliableHeading != _repHeading) {
          _repHeading = reliableHeading;
          _initCurrentLocationIcon();
        }
        widget.api.updateRepLocation(position.latitude, position.longitude);
        _computeBeatRoute();
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15.0),
        );
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (mounted) {
          final reliableHeading = RouteDeviationDetector.extractReliableHeading(pos);
          if (reliableHeading != _repHeading) {
            _repHeading = reliableHeading;
            _initCurrentLocationIcon();
          }
          widget.api.updateRepLocation(pos.latitude, pos.longitude);
          _handleGpsMovementAndDeviation(pos);
        }
      });
    } catch (_) {}
  }

  /// Calculates or refreshes the full sequential road route across the assigned beat.
  Future<void> _computeBeatRoute() async {
    if (_isRouteEngineCalculating || !mounted) return;
    setState(() => _isRouteEngineCalculating = true);

    try {
      final repPos = LatLng(widget.api.currentRepLat, widget.api.currentRepLng);
      final assigned = widget.api.assignedRouteShops;
      final plan = await _routeEngine.buildBeatRoute(
        repPosition: repPos,
        assignedShops: assigned,
        beatId: widget.api.activeTerritory,
        beatName: widget.api.activeTerritoryName,
        godown: _activeGodownHub(),
      );
      if (mounted) {
        setState(() {
          _currentRoutePlan = plan;
          _isRouteEngineCalculating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRouteEngineCalculating = false);
    }
  }

  /// Evaluates GPS position against the active road leg to detect deviation and reroute.
  void _handleGpsMovementAndDeviation(Position pos) {
    if (_currentRoutePlan == null || _currentRoutePlan!.legs.isEmpty) return;

    final activeLeg = _currentRoutePlan!.activeLeg;
    if (activeLeg == null || activeLeg.geometry.isEmpty) return;

    final hasDeviated = _deviationDetector.checkDeviation(
      pos: pos,
      activePolyline: activeLeg.geometry,
    );

    if (hasDeviated) {
      final assigned = widget.api.assignedRouteShops;
      final nextIdx = _findNextPendingIndex(assigned);
      if (nextIdx != null && nextIdx < assigned.length) {
        final nextShop = assigned[nextIdx];
        _routeEngine.rerouteActiveLeg(
          newRepPosition: LatLng(pos.latitude, pos.longitude),
          nextShop: nextShop,
        ).then((updatedPlan) {
          if (mounted && updatedPlan != null) {
            setState(() => _currentRoutePlan = updatedPlan);
          }
        });
      }
    }
  }

  /// Launches Google Maps turn-by-turn navigation directly to the next pending stop.
  Future<void> _launchNextShopNavigation() async {
    final assigned = widget.api.assignedRouteShops;
    final nextIdx = _findNextPendingIndex(assigned);
    if (nextIdx == null || nextIdx >= assigned.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All assigned shops are already visited!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nextShop = assigned[nextIdx];
    widget.onNavigateTab(2);
    if (nextShop.latitude == null || nextShop.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coordinates unavailable for ${nextShop.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final launched = await ExternalNavigationService.launchTurnByTurn(
      latitude: nextShop.latitude!,
      longitude: nextShop.longitude!,
      destinationLabel: nextShop.name,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening Google Maps navigation to ${nextShop.name}...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _initCurrentLocationIcon() async {
    try {
      final repIcon = await _markerCache.getRepBlueDot(withHeadingCone: _repHeading != null);
      final godownIcon = await _markerCache.getGodownMarker();
      if (mounted) {
        setState(() {
          _currentLocationBlueDotIcon = repIcon;
          _godownMarkerIcon = godownIcon;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stopwatchTimer?.cancel();
    _googleMapController?.dispose();
    super.dispose();
  }

  void _openAddShopSheet() async {
    final newShop = await AddShopSheet.show(
      context,
      api: widget.api,
      defaultRouteId: widget.api.activeTerritory == 'jodhpur' ? 'route_sardarpura_02' : 'route_chd_mohali_01',
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
    final assignedShops = widget.api.dynamicRoadRouteShops;
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

    if (_selectedStopIndex >= assignedShops.length && assignedShops.isNotEmpty) {
      _selectedStopIndex = 0;
    }
    final selectedShop = assignedShops.isNotEmpty ? assignedShops[_selectedStopIndex] : null;
    final locatedShops = assignedShops.where((s) => s.latitude != null && s.longitude != null).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. EMBEDDED INTERACTIVE ROUTE MAP (Directly below navbar)
          _buildInteractiveMap(locatedShops, selectedShop, activeShop, strings),

          // 1b. PHASE 3 ROUTE INTELLIGENCE & NAVIGATION CARD
          RouteInfoPanel(
            plan: _currentRoutePlan,
            isCalculating: _isRouteEngineCalculating,
            onNavigatePressed: _launchNextShopNavigation,
          ),

          const SizedBox(height: 8),

          // 2. TODAY'S ASSIGNED BEAT BANNER (Sardarpura & Nai Sadak Route)
          _buildAssignedBeatCard(assignedShops, selectedShop, strings),

          const SizedBox(height: 16),

          // 3. SALES PERFORMANCE & FLEET COMPETITION LEADERBOARD
          _buildSalesPerformanceAndLeaderboard(strings),

          const SizedBox(height: 18),

          // 4. TIMEFRAME SELECTOR CHIPS
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
                    Text(
                      AppStrings.tr('no_orders_booked_today'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AirbnbTheme.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.noOrdersBeatPrompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => widget.onNavigateTab(1),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(AppStrings.tr('book_first_order')),
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









  List<LatLng> _buildRoadSegment(LatLng from, LatLng to) {
    final points = <LatLng>[from];

    // Check if points are in Jodhpur territory (lat < 28.5)
    final bool isJodhpur = from.latitude < 28.5 && to.latitude < 28.5;

    if (isJodhpur) {
      final bool fromSardarpura = from.latitude < 26.2860;
      final bool toSardarpura = to.latitude < 26.2860;

      if (fromSardarpura && toSardarpura) {
        // Sardarpura internal grid (via B/C Road intersections)
        points.add(LatLng(from.latitude, to.longitude));
      } else if (!fromSardarpura && !toSardarpura) {
        // Old City Bazaar / Nai Sadak / Sojati Gate corridor
        points.add(LatLng(to.latitude, from.longitude));
      } else {
        // Arterial corridor connecting Sardarpura and Nai Sadak (via Sojati Gate junction)
        const sojatiGateJunction = LatLng(26.2890, 73.0190);
        points.add(LatLng(from.latitude, sojatiGateJunction.longitude));
        points.add(sojatiGateJunction);
        points.add(LatLng(to.latitude, sojatiGateJunction.longitude));
      }
    } else {
      // Chandigarh & Mohali territory (lat >= 28.5)
      final bool fromChandigarh = from.latitude >= 30.7100;
      final bool toChandigarh = to.latitude >= 30.7100;

      if (fromChandigarh && toChandigarh) {
        // Chandigarh sector grid routing (via sector dividing road & roundabout)
        points.add(LatLng(from.latitude, to.longitude));
      } else if (!fromChandigarh && !toChandigarh) {
        // Mohali SAS Nagar phase grid routing
        points.add(LatLng(to.latitude, from.longitude));
      } else {
        // Chandigarh-Mohali Border arterial (via Sector 43 / Phase 3B2 Border Chowk)
        const borderChowk = LatLng(30.7090, 76.7370);
        points.add(LatLng(from.latitude, borderChowk.longitude));
        points.add(borderChowk);
        points.add(LatLng(to.latitude, borderChowk.longitude));
      }
    }

    points.add(to);
    return points;
  }

  Set<Polyline> _buildColorCodedRoutePolylines(List<RetailerShop> shops) {
    final polylines = <Polyline>{};
    if (shops.isEmpty) return polylines;

    // If RouteEngine has calculated real road geometry, render real road polylines
    if (_currentRoutePlan != null && _currentRoutePlan!.legs.isNotEmpty) {
      final legs = _currentRoutePlan!.legs;
      for (int i = 0; i < legs.length; i++) {
        final leg = legs[i];
        final isFirstActive = i == 0;
        final isApprox = leg.isApproximate;

        polylines.add(
          Polyline(
            polylineId: PolylineId('engine_leg_${i}_${leg.destinationId}'),
            points: leg.geometry,
            color: isFirstActive
                ? const Color(0xFF1A73E8) // Prominent Blue for Active Navigation Leg
                : const Color(0xFFE53935), // Red for pending beat legs
            width: isFirstActive ? 6 : 4,
            patterns: isApprox ? [PatternItem.dash(16), PatternItem.gap(10)] : const [],
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
      return polylines;
    }

    // Fallback: Grid-based road corridor lines from Phase 2
    final firstLocated = shops.where((s) => s.latitude != null && s.longitude != null).firstOrNull;
    if (firstLocated == null) return polylines;

    final repLat = widget.api.currentRepLat;
    final repLng = widget.api.currentRepLng;
    final distToFirst = ApiService.calculateDistanceMeters(repLat, repLng, firstLocated.latitude!, firstLocated.longitude!);

    LatLng prevPoint;
    int startIndex = 0;
    if (distToFirst < 35000) {
      prevPoint = LatLng(repLat, repLng);
      startIndex = 0;
    } else {
      prevPoint = LatLng(firstLocated.latitude!, firstLocated.longitude!);
      startIndex = 1;
    }

    for (int i = startIndex; i < shops.length; i++) {
      final s = shops[i];
      if (s.latitude == null || s.longitude == null) continue;
      final currentTarget = LatLng(s.latitude!, s.longitude!);

      final roadPoints = _buildRoadSegment(prevPoint, currentTarget);
      final bool isVisitedOrChecked = s.visitedToday || s.isCheckedIn;

      polylines.add(
        Polyline(
          polylineId: PolylineId('segment_${i}_${s.id}'),
          points: roadPoints,
          color: isVisitedOrChecked ? const Color(0xFF00B894) : const Color(0xFFE53935),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );

      prevPoint = currentTarget;
    }

    return polylines;
  }

  void _fitRouteBounds(List<RetailerShop> locatedShops) {
    if (_googleMapController == null) return;
    if (locatedShops.isEmpty) {
      final defaultLat = widget.api.activeTerritory == 'jodhpur' ? 26.2850 : 30.7225;
      final defaultLng = widget.api.activeTerritory == 'jodhpur' ? 73.0180 : 76.7620;
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(defaultLat, defaultLng), 14.5),
      );
      return;
    }

    final points = <LatLng>[
      ...locatedShops.map((s) => LatLng(s.latitude!, s.longitude!)),
    ];

    // Only include rep's phone location if it is nearby this city's cluster (< 35km)
    final repLat = widget.api.currentRepLat;
    final repLng = widget.api.currentRepLng;
    final isRepNearby = points.any((p) => ApiService.calculateDistanceMeters(repLat, repLng, p.latitude, p.longitude) < 35000);
    if (isRepNearby) {
      points.add(LatLng(repLat, repLng));
    }
    if (points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    if (minLat == maxLat) {
      minLat -= 0.005;
      maxLat += 0.005;
    }
    if (minLng == maxLng) {
      minLng -= 0.005;
      maxLng += 0.005;
    }
    try {
      _googleMapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          55.0,
        ),
      );
    } catch (_) {}
  }

  WarehouseHub? _activeGodownHub() {
    final hubs = widget.api.warehouseHubs.where((h) => h.latitude != null && h.longitude != null).toList();
    if (hubs.isEmpty) return null;
    final isJodhpur = widget.api.activeTerritory == 'jodhpur';
    for (final h in hubs) {
      final isJodhpurHub = h.latitude! < 29.0;
      if (isJodhpur == isJodhpurHub) return h;
    }
    return hubs.first;
  }

  int? _findNextPendingIndex(List<RetailerShop> shops) {
    for (int i = 0; i < shops.length; i++) {
      if (!shops[i].visitedToday && !shops[i].isCheckedIn) return i;
    }
    return null;
  }

  void _recenterPendingRoute(List<RetailerShop> locatedShops) {
    final pending = locatedShops.where((s) => !s.visitedToday && !s.isCheckedIn).toList();
    if (pending.isEmpty) {
      _fitRouteBounds(locatedShops);
      return;
    }
    _fitRouteBounds(pending);
  }

  void _focusNextPendingShop(List<RetailerShop> locatedShops) {
    final nextIdx = _findNextPendingIndex(locatedShops);
    if (nextIdx == null) {
      _fitRouteBounds(locatedShops);
      return;
    }
    final nextShop = locatedShops[nextIdx];
    setState(() => _selectedStopIndex = nextIdx);
    _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(nextShop.latitude!, nextShop.longitude!), 16.2),
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = AirbnbTheme.dark,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AirbnbTheme.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
            ],
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
      ),
    );
  }

  Set<Marker> _buildPhase2Markers(
    List<RetailerShop> locatedShops,
    int? nextPendingIndex,
  ) {
    final visitedSet = <int>{};
    final checkedInSet = <int>{};
    for (int i = 0; i < locatedShops.length; i++) {
      if (locatedShops[i].visitedToday) {
        visitedSet.add(i);
      } else if (locatedShops[i].isCheckedIn) {
        checkedInSet.add(i);
      }
    }
    _markerCache.prewarmShopMarkers(
      count: locatedShops.length,
      visitedIndices: visitedSet,
      checkedInIndices: checkedInSet,
      nextPendingIndex: nextPendingIndex,
      onUpdated: () {
        if (mounted) setState(() {});
      },
    );

    final markers = <Marker>{
      // 1. Live Salesperson GPS Marker with optional heading cone
      Marker(
        markerId: const MarkerId('current_location_user'),
        position: LatLng(widget.api.currentRepLat, widget.api.currentRepLng),
        icon: _currentLocationBlueDotIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: _repHeading ?? 0.0,
        infoWindow: const InfoWindow(
          title: 'Current Location (You Are Here)',
          snippet: 'Live GPS Position',
        ),
        zIndexInt: 100,
      ),
    };

    // 2. Starting Godown / Warehouse Marker
    final godown = _activeGodownHub();
    if (godown != null && godown.latitude != null && godown.longitude != null) {
      markers.add(
        Marker(
          markerId: MarkerId('godown_${godown.id}'),
          position: LatLng(godown.latitude!, godown.longitude!),
          icon: _godownMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: godown.name,
            snippet: 'Starting Godown • ${godown.address}',
          ),
          zIndexInt: 80,
        ),
      );
    }

    // 3. Lightweight Grid Clustering for large routes (> 25 stops) when zoomed out
    if (locatedShops.length > 25 && _currentZoom < 13.0) {
      const double gridDeg = 0.012;
      final buckets = <String, List<int>>{};
      for (int i = 0; i < locatedShops.length; i++) {
        final s = locatedShops[i];
        final gx = (s.latitude! / gridDeg).floor();
        final gy = (s.longitude! / gridDeg).floor();
        buckets.putIfAbsent('${gx}_$gy', () => []).add(i);
      }
      for (final entry in buckets.entries) {
        final indices = entry.value;
        if (indices.length == 1) {
          markers.add(_buildSingleShopMarker(locatedShops, indices.first, nextPendingIndex));
        } else {
          double avgLat = 0;
          double avgLng = 0;
          for (final idx in indices) {
            avgLat += locatedShops[idx].latitude!;
            avgLng += locatedShops[idx].longitude!;
          }
          avgLat /= indices.length;
          avgLng /= indices.length;
          final clusterIcon = _markerCache.getCached('cluster_${indices.length}');
          if (clusterIcon == null) {
            _markerCache.getClusterMarker(indices.length).then((_) {
              if (mounted) setState(() {});
            });
          }
          markers.add(
            Marker(
              markerId: MarkerId('cluster_${entry.key}'),
              position: LatLng(avgLat, avgLng),
              icon: clusterIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: InfoWindow(
                title: '${indices.length} Shops in Area',
                snippet: 'Tap to zoom in',
              ),
              onTap: () {
                _googleMapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(LatLng(avgLat, avgLng), 14.5),
                );
              },
            ),
          );
        }
      }
      return markers;
    }

    // 4. Numbered Shop Markers (Visited=Green, Next Pending=Bright Amber, Pending=Red)
    for (int i = 0; i < locatedShops.length; i++) {
      markers.add(_buildSingleShopMarker(locatedShops, i, nextPendingIndex));
    }

    return markers;
  }

  Marker _buildSingleShopMarker(
    List<RetailerShop> locatedShops,
    int idx,
    int? nextPendingIndex,
  ) {
    final s = locatedShops[idx];
    final isVisited = s.visitedToday;
    final isCheckedIn = !isVisited && s.isCheckedIn;
    final isNext = !isVisited && !isCheckedIn && nextPendingIndex == idx;
    final stopNum = idx + 1;

    final key = SalesMapMarkerCache.shopKey(
      stopNum,
      isVisited: isVisited,
      isCheckedIn: isCheckedIn,
      isNext: isNext,
    );
    final cachedIcon = _markerCache.getCached(key);
    final fallbackHue = isVisited
        ? BitmapDescriptor.hueGreen
        : (isCheckedIn
            ? BitmapDescriptor.hueCyan
            : (isNext ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed));

    final distM = ApiService.calculateRoadDistanceMeters(
      widget.api.currentRepLat,
      widget.api.currentRepLng,
      s.latitude!,
      s.longitude!,
    );
    final distStr = distM < 1000 ? '${distM.toStringAsFixed(0)} m' : '${(distM / 1000).toStringAsFixed(1)} km';

    return Marker(
      markerId: MarkerId(s.id),
      position: LatLng(s.latitude!, s.longitude!),
      icon: cachedIcon ?? BitmapDescriptor.defaultMarkerWithHue(fallbackHue),
      anchor: const Offset(0.5, 0.88),
      zIndexInt: isCheckedIn ? 95 : (isNext ? 90 : (isVisited ? 40 : 60)),
      infoWindow: InfoWindow(
        title: isVisited
            ? '✓ Completed #$stopNum: ${s.name}'
            : (isCheckedIn
                ? '● Visiting #$stopNum: ${s.name}'
                : (isNext ? '★ Next #$stopNum: ${s.name} ($distStr)' : 'Stop #$stopNum: ${s.name} ($distStr)')),
        snippet: isVisited
            ? 'Visit Completed • Time spent: ${s.totalTimeSpentFormatted}'
            : (isCheckedIn ? 'Currently Checked In • Active Visit' : (isNext ? 'Next Recommended Stop' : 'Pending Stop')),
      ),
      onTap: () {
        setState(() {
          _selectedStopIndex = idx;
        });
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(s.latitude!, s.longitude!)),
        );
      },
    );
  }

  Widget _buildInteractiveMap(
    List<RetailerShop> locatedShops,
    RetailerShop? selectedShop,
    RetailerShop? activeShop,
    AppStrings strings,
  ) {
    final nextPendingIndex = _findNextPendingIndex(locatedShops);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: _isMapFullscreen ? 480 : 260,
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
          if (locatedShops.isNotEmpty)
            GoogleMap(
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.api.currentRepLat, widget.api.currentRepLng),
                zoom: 15.0,
              ),
              mapType: _mapType,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onCameraMove: (camPos) {
                _currentZoom = camPos.zoom;
              },
              circles: {
                // Outer Google Maps accuracy circle
                Circle(
                  circleId: const CircleId('current_location_outer_accuracy_circle'),
                  center: LatLng(widget.api.currentRepLat, widget.api.currentRepLng),
                  radius: 120,
                  fillColor: const Color(0x201A73E8),
                  strokeColor: const Color(0x661A73E8),
                  strokeWidth: 2,
                  zIndex: 1,
                ),
                // Inner Google Maps pulse circle
                Circle(
                  circleId: const CircleId('current_location_inner_pulse_circle'),
                  center: LatLng(widget.api.currentRepLat, widget.api.currentRepLng),
                  radius: 45,
                  fillColor: const Color(0x351A73E8),
                  strokeColor: const Color(0x991A73E8),
                  strokeWidth: 2,
                  zIndex: 2,
                ),
              },
              markers: _buildPhase2Markers(locatedShops, nextPendingIndex),
              polylines: _buildColorCodedRoutePolylines(locatedShops),
              onMapCreated: (ctrl) {
                _googleMapController = ctrl;
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (mounted) _fitRouteBounds(locatedShops);
                });
              },
            ),

          // Top-Right Map Mode Controls (Fullscreen, Satellite)
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mapControlButton(
                  icon: _isMapFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  tooltip: _isMapFullscreen ? 'Exit Fullscreen' : 'Fullscreen Map',
                  onTap: () => setState(() => _isMapFullscreen = !_isMapFullscreen),
                ),
                const SizedBox(width: 5),
                _mapControlButton(
                  icon: _mapType == MapType.normal ? Icons.satellite_alt : Icons.map,
                  tooltip: 'Switch Map Type',
                  onTap: () => setState(() {
                    _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
                  }),
                ),
              ],
            ),
          ),

          // Second-Row Top-Left Route Controls (My Location, Focus Next, Recenter, Show All)
          Positioned(
            top: 42,
            left: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mapControlButton(
                  icon: Icons.my_location,
                  tooltip: 'My Location',
                  iconColor: const Color(0xFF1A73E8),
                  onTap: () async {
                    try {
                      final pos = await Geolocator.getCurrentPosition(
                        locationSettings: const LocationSettings(
                          accuracy: LocationAccuracy.high,
                          timeLimit: Duration(seconds: 4),
                        ),
                      );
                      if (mounted) {
                        final h = RouteDeviationDetector.extractReliableHeading(pos);
                        if (h != _repHeading) {
                          _repHeading = h;
                          _initCurrentLocationIcon();
                        }
                        widget.api.updateRepLocation(pos.latitude, pos.longitude);
                      }
                    } catch (_) {}
                    if (!mounted) return;
                    _googleMapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(widget.api.currentRepLat, widget.api.currentRepLng),
                        16.0,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 5),
                _mapControlButton(
                  icon: Icons.near_me_rounded,
                  tooltip: 'Focus Next Shop',
                  iconColor: const Color(0xFFF59E0B),
                  onTap: () => _focusNextPendingShop(locatedShops),
                ),
                const SizedBox(width: 5),
                _mapControlButton(
                  icon: Icons.alt_route_rounded,
                  tooltip: 'Recenter Route',
                  iconColor: AirbnbTheme.jodhpurBlue,
                  onTap: () => _recenterPendingRoute(locatedShops),
                ),
                const SizedBox(width: 5),
                _mapControlButton(
                  icon: Icons.fit_screen_outlined,
                  tooltip: 'Show All Shops',
                  onTap: () => _fitRouteBounds(locatedShops),
                ),
              ],
            ),
          ),

          // Right-Side Compact Zoom In / Zoom Out Controls
          Positioned(
            right: 10,
            top: 52,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mapControlButton(
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: () => _googleMapController?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 4),
                _mapControlButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: () => _googleMapController?.animateCamera(CameraUpdate.zoomOut()),
                ),
              ],
            ),
          ),

          // Route Legend Pill (top left)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AirbnbTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.api.activeTerritoryShortName,
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AirbnbTheme.coral),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00B894),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Visited', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF00B894))),
                  const SizedBox(width: 7),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Pending Road', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
                ],
              ),
            ),
          ),

          // Floating "YOU ARE HERE" pill on bottom left
          Positioned(
            bottom: 10,
            left: 10,
            child: InkWell(
              onTap: () {
                _googleMapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(widget.api.currentRepLat, widget.api.currentRepLng),
                    15.5,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1A73E8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A73E8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '📍 YOU ARE HERE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                  ],
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
              icon: const Icon(Icons.add_business_outlined, size: 16),
              label: const Text(
                '+ Add Shop',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbTheme.coral,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedBeatCard(
    List<RetailerShop> assignedShops,
    RetailerShop? selectedShop,
    AppStrings strings,
  ) {
    return Container(
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
          // City / Territory Selector Switcher Pills
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const ValueKey('territory_pill_chd'),
                    onTap: () {
                      widget.api.setActiveTerritory('chandigarh_mohali');
                      setState(() => _selectedStopIndex = 0);
                      final shops = widget.api.dynamicRoadRouteShops;
                      final located = shops.where((s) => s.latitude != null && s.longitude != null).toList();
                      _fitRouteBounds(located);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7.5),
                      decoration: BoxDecoration(
                        color: widget.api.activeTerritory == 'chandigarh_mohali' ? AirbnbTheme.coral : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_city_rounded,
                            size: 14,
                            color: widget.api.activeTerritory == 'chandigarh_mohali' ? Colors.white : Colors.white70,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Chandigarh & Mohali',
                            style: TextStyle(
                              color: widget.api.activeTerritory == 'chandigarh_mohali' ? Colors.white : Colors.white70,
                              fontSize: 11.5,
                              fontWeight: widget.api.activeTerritory == 'chandigarh_mohali' ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    key: const ValueKey('territory_pill_jdh'),
                    onTap: () {
                      widget.api.setActiveTerritory('jodhpur');
                      setState(() => _selectedStopIndex = 0);
                      final shops = widget.api.dynamicRoadRouteShops;
                      final located = shops.where((s) => s.latitude != null && s.longitude != null).toList();
                      _fitRouteBounds(located);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7.5),
                      decoration: BoxDecoration(
                        color: widget.api.activeTerritory == 'jodhpur' ? AirbnbTheme.coral : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fort_rounded,
                            size: 14,
                            color: widget.api.activeTerritory == 'jodhpur' ? Colors.white : Colors.white70,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Jodhpur (Sardarpura)',
                            style: TextStyle(
                              color: widget.api.activeTerritory == 'jodhpur' ? Colors.white : Colors.white70,
                              fontSize: 11.5,
                              fontWeight: widget.api.activeTerritory == 'jodhpur' ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.api.activeTerritoryName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Road-Aware Nearest Route (Dynamic 0-Crossing Road Grid) • ${assignedShops.length} Active Stops',
            style: const TextStyle(
              color: Color(0xFFB2BEC3),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const ValueKey('continue_route_btn'),
              onPressed: _launchNextShopNavigation,
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: Text(strings.t('continue_route'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbTheme.coral,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              ),
            ),
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
                  final stopNumber = idx + 1;
                  final isFirst = idx == 0;
                  final isSecond = idx == 1;
                  final distM = (shop.latitude != null && shop.longitude != null)
                      ? ApiService.calculateRoadDistanceMeters(
                          widget.api.currentRepLat,
                          widget.api.currentRepLng,
                          shop.latitude!,
                          shop.longitude!,
                        )
                      : 0.0;
                  final distStr = distM < 1000 ? '${distM.toStringAsFixed(0)}m' : '${(distM / 1000).toStringAsFixed(1)}km';

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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isFirst
                                    ? (isSel ? Colors.white : Colors.amber)
                                    : (isSel ? Colors.white.withValues(alpha: 0.25) : Colors.black26),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isFirst ? '#1 1st' : (isSecond ? '#2 2nd' : '#$stopNumber'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  color: isFirst
                                      ? (isSel ? AirbnbTheme.coral : Colors.black)
                                      : (isSel ? Colors.white : const Color(0xFFB2BEC3)),
                                ),
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
                            const SizedBox(width: 4),
                            Text(
                              distStr,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: isSel ? Colors.white70 : const Color(0xFF94A3B8),
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
                  // Sequential Priority Tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _selectedStopIndex == 0
                              ? const Color(0xFFFEF3C7)
                              : (_selectedStopIndex == 1 ? const Color(0xFFEFF6FF) : AirbnbTheme.lightGrey),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _selectedStopIndex == 0
                                ? const Color(0xFFF59E0B)
                                : (_selectedStopIndex == 1 ? const Color(0xFF60A5FA) : AirbnbTheme.border),
                          ),
                        ),
                        child: Text(
                          _selectedStopIndex == 0
                              ? '🎯 STOP 1 • VISIT FIRST (NEAREST TO YOU)'
                              : (_selectedStopIndex == 1 ? '⏩ STOP 2 • VISIT SECOND' : 'STOP #${_selectedStopIndex + 1} ON ROUTE'),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: _selectedStopIndex == 0
                                ? const Color(0xFFB45309)
                                : (_selectedStopIndex == 1 ? const Color(0xFF1D4ED8) : AirbnbTheme.dark),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                                  '#${_selectedStopIndex + 1}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
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
                  // Time Spent & Visit Status Indicator
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: selectedShop.isCheckedIn
                          ? const Color(0xFF00B894).withValues(alpha: 0.12)
                          : (selectedShop.visitedToday ? const Color(0xFFEFF6FF) : AirbnbTheme.lightGrey),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedShop.isCheckedIn
                            ? const Color(0xFF00B894)
                            : (selectedShop.visitedToday ? const Color(0xFF60A5FA) : AirbnbTheme.border),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedShop.isCheckedIn
                              ? Icons.timer
                              : (selectedShop.visitedToday ? Icons.check_circle : Icons.schedule),
                          size: 15,
                          color: selectedShop.isCheckedIn
                              ? const Color(0xFF00897B)
                              : (selectedShop.visitedToday ? const Color(0xFF2563EB) : AirbnbTheme.grey),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            selectedShop.isCheckedIn
                                ? '🟢 CHECKED IN • Time Spent: ${selectedShop.activeVisitFormatted}'
                                : (selectedShop.visitedToday
                                    ? '✓ VISITED TODAY • Time Spent: ${selectedShop.totalTimeSpentFormatted}'
                                    : '⏱️ Not Visited (0m spent today)'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: selectedShop.isCheckedIn
                                  ? const Color(0xFF00897B)
                                  : (selectedShop.visitedToday ? const Color(0xFF1E40AF) : AirbnbTheme.dark),
                            ),
                          ),
                        ),
                        if (selectedShop.todayOrderTotalPaise > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.coral.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '₹${(selectedShop.todayOrderTotalPaise / 100).toStringAsFixed(0)} Booked',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AirbnbTheme.coral),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Action row
                  Row(
                    children: [
                      Expanded(
                        child: selectedShop.isCheckedIn
                            ? ElevatedButton.icon(
                                onPressed: () {
                                  final elapsed = widget.api.endShopVisit(selectedShop.id);
                                  final nextSequence = widget.api.dynamicRoadRouteShops;
                                  final unvisited = nextSequence.where((s) => !s.visitedToday && !s.isSkipped).toList();
                                  if (unvisited.isNotEmpty) {
                                    final nextShop = unvisited.first;
                                    final nextIdx = nextSequence.indexOf(nextShop);
                                    setState(() {
                                      _selectedStopIndex = nextIdx != -1 ? nextIdx : 0;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF00897B),
                                        duration: const Duration(seconds: 4),
                                        content: Text('✓ Checked off ${selectedShop.name}! Spent: ${RetailerShop.formatDuration(elapsed)}.\nNext Stop: ${nextShop.name}'),
                                      ),
                                    );
                                  } else {
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF00897B),
                                        content: Text('✓ Checked off ${selectedShop.name}! Spent: ${RetailerShop.formatDuration(elapsed)}.\nAll route stops completed!'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check_circle_outline, size: 14),
                                label: const Text('Check-Off / End Visit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: () {
                                  widget.api.startShopVisit(selectedShop.id);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AirbnbTheme.coral,
                                      content: Text('🟢 Checked in at ${selectedShop.name}. Stopwatch active!'),
                                    ),
                                  );
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
                          if (!selectedShop.isCheckedIn) {
                            widget.api.startShopVisit(selectedShop.id);
                          }
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
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          if (selectedShop.latitude != null && selectedShop.longitude != null) {
                            _googleMapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(selectedShop.latitude!, selectedShop.longitude!),
                                16.5,
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🧭 Navigating to Stop #${_selectedStopIndex + 1}: ${selectedShop.name}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.navigation_outlined, size: 14),
                        label: const Text('Navigate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A73E8),
                          side: const BorderSide(color: Color(0xFF1A73E8)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    );
  }

  Widget _buildSalesPerformanceAndLeaderboard(AppStrings strings) {
    final leaderboard = widget.api.getSalesLeaderboard();
    final currentRep = leaderboard.firstWhere(
      (r) => r.isCurrentRep,
      orElse: () => leaderboard.first,
    );
    final myRank = leaderboard.indexOf(currentRep) + 1;
    final topRep = leaderboard.first;
    final double gapToLeader = (topRep.salesRevenueRupees - currentRep.salesRevenueRupees).clamp(0.0, double.infinity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AirbnbTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'FLEET COMPETITION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AirbnbTheme.grey,
                        ),
                      ),
                      Text(
                        'Sales Rep Leaderboard',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AirbnbTheme.dark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Rank #$myRank of ${leaderboard.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Current Sales Rep Performance Hero Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                  const Color(0xFF3B82F6).withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AirbnbTheme.jodhpurBlue,
                          child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentRep.repName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                            ),
                            Text(
                              currentRep.beatName,
                              style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentRep.badge,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Target Achievement Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${currentRep.salesRevenueRupees.toStringAsFixed(0)} achieved',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                    ),
                    Text(
                      'Target: ₹${currentRep.targetRevenueRupees.toStringAsFixed(0)} (${currentRep.targetAchievementPercent.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AirbnbTheme.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (currentRep.targetAchievementPercent / 100.0).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                  ),
                ),
                const SizedBox(height: 8),

                // Metrics Chips
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AirbnbTheme.border),
                        ),
                        child: Column(
                          children: [
                            const Text('Strike Rate', style: TextStyle(fontSize: 9.5, color: AirbnbTheme.grey, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${currentRep.strikeRatePercent.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AirbnbTheme.border),
                        ),
                        child: Column(
                          children: [
                            const Text('Visited Shops', style: TextStyle(fontSize: 9.5, color: AirbnbTheme.grey, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${currentRep.visitsCompleted}/${currentRep.totalAssignedShops}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AirbnbTheme.border),
                        ),
                        child: Column(
                          children: [
                            const Text('Orders Booked', style: TextStyle(fontSize: 9.5, color: AirbnbTheme.grey, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${currentRep.ordersBooked}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (gapToLeader > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '🔥 Only ₹${gapToLeader.toStringAsFixed(0)} needed to catch #${topRep.repName} for 1st place!',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Territory Peer Rankings List
          const Text(
            'TODAY\'S FLEET RANKINGS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AirbnbTheme.grey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ...leaderboard.asMap().entries.map((entry) {
            final idx = entry.key;
            final rep = entry.value;
            final rank = idx + 1;
            final isMe = rep.isCurrentRep;

            String medal = '#$rank';
            Color rankColor = const Color(0xFF64748B);
            if (rank == 1) {
              medal = '🥇';
              rankColor = const Color(0xFFF59E0B);
            } else if (rank == 2) {
              medal = '🥈';
              rankColor = const Color(0xFF94A3B8);
            } else if (rank == 3) {
              medal = '🥉';
              rankColor = const Color(0xFFB45309);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFEFF6FF) : AirbnbTheme.lightGrey,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isMe ? const Color(0xFF3B82F6) : Colors.transparent,
                  width: isMe ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      medal,
                      style: TextStyle(fontSize: rank <= 3 ? 15 : 12, fontWeight: FontWeight.w900, color: rankColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              rep.repName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                                color: isMe ? const Color(0xFF1E3A8A) : AirbnbTheme.dark,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${rep.beatName} • ${rep.visitsCompleted}/${rep.totalAssignedShops} visits',
                          style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${rep.salesRevenueRupees.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                      ),
                      Text(
                        rep.badge,
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AirbnbTheme.grey),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
