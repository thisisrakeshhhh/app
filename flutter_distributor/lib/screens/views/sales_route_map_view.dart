import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';

/// Zomato-style Route & Shop Map View for Sales Representative.
/// Displays assigned beat route (Points A -> B -> C -> D), stops,
/// address breakdown (SCO No, Gali No, Landmark, Class Badge),
/// live visit timer, order value tracker, and add/remove stop from route.
class SalesRouteMapView extends StatefulWidget {
  final ApiService api;
  final Function(int targetTab)? onNavigateTab;

  const SalesRouteMapView({
    super.key,
    required this.api,
    this.onNavigateTab,
  });

  @override
  State<SalesRouteMapView> createState() => _SalesRouteMapViewState();
}

class _SalesRouteMapViewState extends State<SalesRouteMapView> {
  int _selectedStopIndex = 0;
  Timer? _visitTimer;
  String _filter = 'All'; // 'All', 'Pending', 'Visited'

  @override
  void initState() {
    super.initState();
    // Update live timer every second if checked in
    _visitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.api.activeVisitShop != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _visitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final allShops = widget.api.retailers;
    final routeShops = widget.api.assignedRouteShops;
    final activeShop = widget.api.activeVisitShop;

    final displayedShops = routeShops.where((s) {
      if (_filter == 'Pending') return !s.visitedToday && !s.isCheckedIn;
      if (_filter == 'Visited') return s.visitedToday;
      return true;
    }).toList();

    final locatedShops = displayedShops.where((s) => s.latitude != null && s.longitude != null).toList();
    final unlocatedShops = displayedShops.where((s) => s.latitude == null || s.longitude == null).toList();

    if (_selectedStopIndex >= displayedShops.length && displayedShops.isNotEmpty) {
      _selectedStopIndex = 0;
    }

    final selectedShop = displayedShops.isNotEmpty
        ? displayedShops[_selectedStopIndex]
        : (allShops.isNotEmpty ? allShops.first : null);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 1. TOP ROUTE CONTROL BAR
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AirbnbTheme.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.coral.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.alt_route_rounded, color: AirbnbTheme.coral, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sardarpura & Clock Tower Beat',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AirbnbTheme.dark),
                                ),
                                Text(
                                  '${routeShops.length} Shops Assigned • ${routeShops.where((s) => s.visitedToday).length} Visited',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AirbnbTheme.lightGrey,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AirbnbTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.alt_route, size: 12, color: AirbnbTheme.grey),
                          const SizedBox(width: 4),
                          Text(strings.t('route_sketch'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'All (${routeShops.length})'),
                      const SizedBox(width: 6),
                      _buildFilterChip('Pending', 'Pending (${routeShops.where((s) => !s.visitedToday).length})'),
                      const SizedBox(width: 6),
                      _buildFilterChip('Visited', 'Visited (${routeShops.where((s) => s.visitedToday).length})'),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.add_location_alt_outlined, size: 14, color: AirbnbTheme.coral),
                        label: const Text('Extra Visits (अतिरिक्त दौरा)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AirbnbTheme.coral)),
                        backgroundColor: AirbnbTheme.coral.withValues(alpha: 0.08),
                        onPressed: () => _showAddRemoveShopsModal(context, allShops),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. INTERACTIVE ROUTE MAP CANVAS (Only plots shops with valid coordinates)
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                GestureDetector(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _ZomatoRouteMapPainter(
                      shops: locatedShops,
                      selectedIndex: selectedShop != null ? locatedShops.indexOf(selectedShop) : -1,
                      activeShopId: activeShop?.id,
                    ),
                  ),
                ),

                // Floating Pin Badges for Direct Tap Selection (Only for shops with valid coordinates)
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    if (locatedShops.isEmpty) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AirbnbTheme.border),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_off_outlined, color: Colors.orange, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                strings.t('location_not_added'),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AirbnbTheme.dark),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${displayedShops.length} shop(s) on this route without coordinates. Listed below.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Stack(
                      children: locatedShops.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final shop = entry.value;
                        final isSelected = shop.id == selectedShop?.id;
                        final isCheckedIn = shop.isCheckedIn;
                        final isVisited = shop.visitedToday;

                        // Real GPS scaled position on canvas
                        final pos = computeShopCanvasPosition(
                          shop: shop,
                          index: idx,
                          totalCount: locatedShops.length,
                          canvasSize: Size(w, h),
                          allShops: locatedShops,
                        );
                        final posX = pos.dx;
                        final posY = pos.dy;
                        final letter = String.fromCharCode(65 + (idx % 26)); // A, B, C, D...

                        return Positioned(
                          left: posX - 24,
                          top: posY - 28,
                          child: GestureDetector(
                            onTap: () {
                              final originalIndex = displayedShops.indexOf(shop);
                              if (originalIndex != -1) {
                                setState(() => _selectedStopIndex = originalIndex);
                              }
                            },
                            child: AnimatedScale(
                              scale: isSelected ? 1.18 : 1.0,
                              duration: const Duration(milliseconds: 180),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected ? AirbnbTheme.coral : AirbnbTheme.border,
                                        width: isSelected ? 1.5 : 0.8,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      shop.name.split(' ').take(2).join(' '),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? AirbnbTheme.coral : AirbnbTheme.dark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isCheckedIn
                                          ? AirbnbTheme.coral
                                          : (isVisited ? AirbnbTheme.success : (isSelected ? AirbnbTheme.jodhpurBlue : const Color(0xFF475569))),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: isVisited
                                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                                          : Text(
                                              letter,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // Map Legend Overlay
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AirbnbTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLegendItem(AirbnbTheme.success, 'Visited (दौरा पूर्ण)'),
                        const SizedBox(height: 3),
                        _buildLegendItem(AirbnbTheme.coral, 'Active Visit (चालू)'),
                        const SizedBox(height: 3),
                        _buildLegendItem(AirbnbTheme.jodhpurBlue, 'Next Stop (अगला)'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Question 6: Dedicated "Location not added" list under map for shops lacking coordinates
          if (unlocatedShops.isNotEmpty)
            Container(
              key: const Key('location_not_added_section'),
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off_outlined, size: 14, color: Colors.deepOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${strings.t('location_not_added')}: ${unlocatedShops.map((s) => s.name).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.deepOrange),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 13, color: AirbnbTheme.coral),
                    label: Text(
                      strings.t('add_location'),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AirbnbTheme.coral),
                    ),
                    onPressed: () {
                      final target = unlocatedShops.first;
                      final targetIdx = displayedShops.indexOf(target);
                      if (targetIdx != -1) {
                        setState(() => _selectedStopIndex = targetIdx);
                      }
                    },
                  ),
                ],
              ),
            ),

          // 3. ZOMATO-STYLE RETAILER DELIVERY CARD (Selected Stop Details)
          if (selectedShop != null)
            _buildZomatoShopCard(context, selectedShop, displayedShops),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
      selected: isSelected,
      selectedColor: AirbnbTheme.coral.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? AirbnbTheme.coral : AirbnbTheme.dark),
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AirbnbTheme.dark)),
      ],
    );
  }

  Widget _buildZomatoShopCard(
    BuildContext context,
    RetailerShop shop,
    List<RetailerShop> displayedShops,
  ) {
    final isCheckedIn = shop.isCheckedIn;
    final isVisited = shop.visitedToday;
    final letter = String.fromCharCode(65 + (_selectedStopIndex % 26));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Stop Badge & Class Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isVisited
                          ? AirbnbTheme.success
                          : (isCheckedIn ? AirbnbTheme.coral : AirbnbTheme.jodhpurBlue),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AirbnbTheme.dark),
                      ),
                      Text(
                        'Prop: ${shop.ownerName} • ${shop.phone}',
                        style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                      ),
                    ],
                  ),
                ],
              ),
              // Class badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getClassColor(shop.classType).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getClassColor(shop.classType).withValues(alpha: 0.4)),
                ),
                child: Text(
                  shop.classType,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _getClassColor(shop.classType),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ZOMATO-STYLE ADDRESS DETAILS (SCO No., Gaali No., Landmark)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AirbnbTheme.lightGrey,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AirbnbTheme.coral),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (shop.unitNo != null || shop.gaaliNo != null) ...[
                        Row(
                          children: [
                            if (shop.unitNo != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  shop.unitNo!,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                                ),
                              ),
                            if (shop.unitNo != null && shop.gaaliNo != null)
                              const SizedBox(width: 6),
                            if (shop.gaaliNo != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  shop.gaaliNo!,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        shop.address.trim().isNotEmpty
                            ? (shop.area.isNotEmpty ? '${shop.address}, ${shop.area}' : shop.address)
                            : 'Address not added',
                        style: TextStyle(
                          fontSize: 11,
                          color: shop.address.trim().isNotEmpty ? AirbnbTheme.dark : AirbnbTheme.grey,
                          fontWeight: FontWeight.w500,
                          fontStyle: shop.address.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (shop.latitude != null && shop.longitude != null)
                            ? 'GPS: ${shop.latitude!.toStringAsFixed(4)}, ${shop.longitude!.toStringAsFixed(4)}'
                            : 'No GPS coordinates recorded',
                        style: const TextStyle(fontSize: 9.5, color: AirbnbTheme.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ACTIVE VISIT TIMER & SALES STATUS (If Checked In)
          if (isCheckedIn)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AirbnbTheme.coral.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AirbnbTheme.coral.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AirbnbTheme.coral, size: 18),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Visit Duration (समय):', style: TextStyle(fontSize: 10, color: AirbnbTheme.grey, fontWeight: FontWeight.w600)),
                          Text(
                            shop.totalTimeSpentFormatted,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AirbnbTheme.coral),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Visit Bookings:', style: TextStyle(fontSize: 10, color: AirbnbTheme.grey, fontWeight: FontWeight.w600)),
                      Text(
                        '₹${(shop.todayOrderTotalPaise / 100.0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AirbnbTheme.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ACTION BUTTONS ROW
          Row(
            children: [
              // In Route / Extra Visit button
              Builder(
                builder: (ctx) {
                  final isAssigned = widget.api.isAssignedBeatShop(shop.id);
                  final isExtra = widget.api.isExtraVisitToday(shop.id);
                  if (isAssigned) {
                    return OutlinedButton.icon(
                      icon: const Icon(Icons.lock_outline, size: 14, color: AirbnbTheme.grey),
                      label: const Text('Assigned Stop', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        side: const BorderSide(color: AirbnbTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Assigned beat shops cannot be removed by sales reps.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  }
                  return OutlinedButton.icon(
                    icon: Icon(isExtra ? Icons.remove_circle_outline : Icons.add_circle_outline, size: 16),
                    label: Text(
                      isExtra ? 'Remove Extra' : 'Add Extra Visit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isExtra ? Colors.red.shade700 : AirbnbTheme.coral,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      side: BorderSide(color: isExtra ? Colors.red.shade200 : AirbnbTheme.coral),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      widget.api.toggleShopInRoute(shop.id);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isExtra
                              ? AppStrings.tr('extra_visit_removed', {'name': shop.name})
                              : AppStrings.tr('extra_visit_added', {'name': shop.name})),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 8),

              // Visit Check-In / Check-Out Button
              Expanded(
                child: isCheckedIn
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('End Visit (समाप्त)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.dark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          widget.api.endShopVisit(shop.id);
                          setState(() {});
                        },
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.login_rounded, size: 16),
                        label: Text(
                          isVisited ? 'Visit Again (दोबारा)' : 'Check In (चेक-इन)',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          widget.api.startShopVisit(shop.id);
                          setState(() {});
                        },
                      ),
              ),
              const SizedBox(width: 8),

              // Book Order Shortcut
              ElevatedButton.icon(
                icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                label: const Text('Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbTheme.jodhpurBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  widget.api.selectShop(shop);
                  widget.onNavigateTab?.call(1); // Navigate to Order Booking Tab
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getClassColor(String classType) {
    switch (classType.toUpperCase()) {
      case 'CLASS_A':
        return Colors.green.shade700;
      case 'CLASS_B':
        return AirbnbTheme.jodhpurBlue;
      case 'CLASS_C':
        return Colors.orange.shade800;
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  void _showAddRemoveShopsModal(BuildContext context, List<RetailerShop> allShops) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extra Visits Today (अतिरिक्त दौरे)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Text(
                'Manager-assigned stops are fixed. You may add extra visits for today (saved in session memory):',
                style: TextStyle(fontSize: 11.5, color: AirbnbTheme.grey),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: allShops.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final s = allShops[i];
                    final isAssigned = widget.api.isAssignedBeatShop(s.id);
                    final isExtra = widget.api.isExtraVisitToday(s.id);
                    return ListTile(
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          if (isAssigned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(color: AirbnbTheme.lightGrey, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Assigned (स्थिर)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
                            )
                          else if (isExtra)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(color: AirbnbTheme.coral.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Extra (अतिरिक्त)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AirbnbTheme.coral)),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        isAssigned
                            ? 'Manager-assigned beat stop (cannot be removed by rep)'
                            : (isExtra ? 'Added as extra visit for today (session memory)' : (s.address.isNotEmpty ? s.address : 'Not in today\'s beat schedule')),
                        style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isAssigned
                          ? const Icon(Icons.lock_outline, size: 18, color: AirbnbTheme.grey)
                          : Switch(
                              value: isExtra,
                              activeThumbColor: AirbnbTheme.coral,
                              onChanged: (val) {
                                widget.api.toggleShopInRoute(s.id);
                                setModalState(() {});
                                setState(() {});
                              },
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Projects real GPS coordinates into canvas bounds when available,
/// or falls back to a deterministic schematic sequential order (Route sketch).
Offset computeShopCanvasPosition({
  required RetailerShop shop,
  required int index,
  required int totalCount,
  required Size canvasSize,
  required List<RetailerShop> allShops,
}) {
  double minLat = double.infinity, maxLat = -double.infinity;
  double minLng = double.infinity, maxLng = -double.infinity;
  int geoCount = 0;

  for (final s in allShops) {
    if (s.latitude != null && s.longitude != null) {
      geoCount++;
      if (s.latitude! < minLat) minLat = s.latitude!;
      if (s.latitude! > maxLat) maxLat = s.latitude!;
      if (s.longitude! < minLng) minLng = s.longitude!;
      if (s.longitude! > maxLng) maxLng = s.longitude!;
    }
  }

  // If at least 2 shops have distinct coordinates, scale into canvas
  if (geoCount >= 2 &&
      (maxLat - minLat).abs() > 0.0001 &&
      (maxLng - minLng).abs() > 0.0001 &&
      shop.latitude != null &&
      shop.longitude != null) {
    final normX = ((shop.longitude! - minLng) / (maxLng - minLng)).clamp(0.0, 1.0);
    final normY = ((maxLat - shop.latitude!) / (maxLat - minLat)).clamp(0.0, 1.0);
    final posX = canvasSize.width * (0.15 + 0.70 * normX);
    final posY = canvasSize.height * (0.15 + 0.70 * normY);
    return Offset(posX, posY);
  }

  // Fallback: deterministic schematic sequential route sketch
  final posX = canvasSize.width * (0.18 + (index % 3) * 0.32);
  final posY = canvasSize.height * (0.15 + (index * 0.22) % 0.70);
  return Offset(posX, posY);
}

/// Custom Canvas Painter rendering street grid, arterial roads, polyline and landmarks
class _ZomatoRouteMapPainter extends CustomPainter {
  final List<RetailerShop> shops;
  final int selectedIndex;
  final String? activeShopId;

  _ZomatoRouteMapPainter({
    required this.shops,
    required this.selectedIndex,
    this.activeShopId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Street Map Canvas Background
    final bgPaint = Paint()..color = const Color(0xFFF8F9FA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. City Blocks & Green Parks
    final parkPaint = Paint()..color = const Color(0xFFE8F5E9);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.05, size.height * 0.06, size.width * 0.28, size.height * 0.16), const Radius.circular(12)), parkPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.62, size.height * 0.58, size.width * 0.32, size.height * 0.24), const Radius.circular(14)), parkPaint);

    // 3. Grid Street Roads (Subtle grey lines)
    final gridRoadPaint = Paint()
      ..color = const Color(0xFFE9ECEF)
      ..strokeWidth = 3.0;

    for (double y = 40; y < size.height; y += 70) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridRoadPaint);
    }
    for (double x = 40; x < size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridRoadPaint);
    }

    // 4. Main Arterial Roads (Bold warm lines)
    final mainRoadPaint = Paint()
      ..color = const Color(0xFFDEE2E6)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round;

    final roadPath = Path()
      ..moveTo(0, size.height * 0.35)
      ..cubicTo(size.width * 0.3, size.height * 0.28, size.width * 0.65, size.height * 0.45, size.width, size.height * 0.40)
      ..moveTo(size.width * 0.45, 0)
      ..lineTo(size.width * 0.50, size.height);
    canvas.drawPath(roadPath, mainRoadPaint);

    if (shops.isEmpty) return;

    // 5. Connect Stops with Directional Route Polyline (Points A -> B -> C -> D)
    final List<Offset> points = [];
    for (var i = 0; i < shops.length; i++) {
      points.add(computeShopCanvasPosition(
        shop: shops[i],
        index: i,
        totalCount: shops.length,
        canvasSize: size,
        allShops: shops,
      ));
    }

    final polylinePaint = Paint()
      ..color = AirbnbTheme.coral.withValues(alpha: 0.75)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePath = Path();
    routePath.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      routePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(routePath, polylinePaint);
  }

  @override
  bool shouldRepaint(covariant _ZomatoRouteMapPainter oldDelegate) => true;
}
