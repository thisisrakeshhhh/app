import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/local/app_database.dart';
import '../../domain/models/phone_sanitizer.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import 'map_pin_picker_dialog.dart';

class AddShopSheet extends StatefulWidget {
  final ApiService api;
  final String? defaultRouteId;
  final VoidCallback? onShopAdded;

  const AddShopSheet({
    super.key,
    required this.api,
    this.defaultRouteId,
    this.onShopAdded,
  });

  static Future<RetailerShop?> show(
    BuildContext context, {
    required ApiService api,
    String? defaultRouteId,
    VoidCallback? onShopAdded,
  }) {
    return showModalBottomSheet<RetailerShop>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddShopSheet(
        api: api,
        defaultRouteId: defaultRouteId,
        onShopAdded: onShopAdded,
      ),
    );
  }

  @override
  State<AddShopSheet> createState() => _AddShopSheetState();
}

class _AddShopSheetState extends State<AddShopSheet> {
  final _nameCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _whatsappSameAsPhone = true;

  final _addressCtrl = TextEditingController();
  late final TextEditingController _areaCtrl;
  final _landmarkCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();

  String? _selectedRouteId;
  List<RouteEntry> _availableRoutes = [];
  RouteEntry? _suggestedNearbyRoute;
  String _selectedShopType = 'SUPERMARKET';
  String _selectedClass = 'CLASS_A'; // 'CLASS_A', 'CLASS_B', 'CLASS_C'
  bool _showMoreDetails = false;
  bool _isSaving = false;

  // Rapido-style Pin Point location state
  double? _latitude;
  double? _longitude;
  double? _accuracyMeters;
  bool _gpsCaptured = false;

  // Route insertion position
  String _routeInsertPosition = 'AT_END'; // 'AT_END', 'AT_START', 'AFTER_SHOP'
  String? _insertAfterShopId;

  // GST & Business Tax details
  String _gstType = 'CONSUMER'; // 'CONSUMER', 'COMPOSITION', 'REGULAR'

  final List<Map<String, dynamic>> _shopCategories = [
    {
      'type': 'SUPERMARKET',
      'label': 'Super Mart',
      'emoji': '🛒',
      'recommendedClass': 'CLASS_A',
      'desc': 'Large format self-service mart',
    },
    {
      'type': 'KIRANA',
      'label': 'Kirana Store',
      'emoji': '🏪',
      'recommendedClass': 'CLASS_B',
      'desc': 'Traditional grocery & staples',
    },
    {
      'type': 'GENERAL_STORE',
      'label': 'General Store',
      'emoji': '🛍️',
      'recommendedClass': 'CLASS_B',
      'desc': 'Daily household items & snacks',
    },
    {
      'type': 'WHOLESALE',
      'label': 'Wholesale Mart',
      'emoji': '📦',
      'recommendedClass': 'CLASS_A',
      'desc': 'Bulk distribution trader',
    },
    {
      'type': 'DAIRY_NEEDS',
      'label': 'Dairy & Daily Needs',
      'emoji': '🥛',
      'recommendedClass': 'CLASS_B',
      'desc': 'Milk, bakery & morning goods',
    },
    {
      'type': 'FARSAN_NAMKEEN',
      'label': 'Namkeen & Sweets',
      'emoji': '🥟',
      'recommendedClass': 'CLASS_B',
      'desc': 'Snacks, namkeen & specialty',
    },
    {
      'type': 'PHARMACY',
      'label': 'Chemist / Pharma',
      'emoji': '💊',
      'recommendedClass': 'CLASS_B',
      'desc': 'Medical & personal care',
    },
    {
      'type': 'PAAN_TEA_STALL',
      'label': 'Paan / Tea Stall',
      'emoji': '☕',
      'recommendedClass': 'CLASS_C',
      'desc': 'High-frequency impulse kiosk',
    },
    {
      'type': 'OTHER',
      'label': 'Other Retail',
      'emoji': '🏬',
      'recommendedClass': 'CLASS_C',
      'desc': 'Independent shop',
    },
  ];

  Color get _selectedClassColor {
    switch (_selectedClass) {
      case 'CLASS_A':
      case 'A':
        return const Color(0xFFD97706);
      case 'CLASS_B':
      case 'B':
        return const Color(0xFF1A73E8);
      case 'CLASS_C':
      case 'C':
        return const Color(0xFF00B894);
      default:
        return AirbnbTheme.dark;
    }
  }

  String get _selectedClassBadge {
    switch (_selectedClass) {
      case 'CLASS_A':
      case 'A':
        return '⭐ Class A (Super Mart)';
      case 'CLASS_B':
      case 'B':
        return '⚡ Class B (Kirana)';
      case 'CLASS_C':
      case 'C':
        return '🏪 Class C (Small Kiosk)';
      default:
        return 'Class B';
    }
  }

  @override
  void initState() {
    super.initState();
    final bool isJodhpur = widget.api.activeTerritory == 'jodhpur';
    _areaCtrl = TextEditingController(
      text: isJodhpur ? 'Sardarpura, Jodhpur' : 'Sector 17, Chandigarh',
    );
    _selectedRouteId = widget.defaultRouteId ?? (isJodhpur ? 'route_sardarpura_02' : 'route_chd_mohali_01');
    _loadRoutes();

    // Auto extract PAN from 15-digit GSTIN
    _gstinCtrl.addListener(_onGstinChanged);
  }

  void _onGstinChanged() {
    final text = _gstinCtrl.text.trim().toUpperCase();
    if (text.length >= 12 && text.length <= 15) {
      // GSTIN format: 2 digit state code + 10 digit PAN + 1 entity + 1 Z + 1 check
      final extractedPan = text.substring(2, 12);
      if (RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(extractedPan)) {
        if (_panCtrl.text != extractedPan) {
          _panCtrl.text = extractedPan;
        }
      }
    }
  }

  Future<void> _loadRoutes() async {
    final routes = await widget.api.getAvailableRoutes();
    if (mounted) {
      final bool isJodhpur = widget.api.activeTerritory == 'jodhpur';
      final preferredRouteId = isJodhpur ? 'route_sardarpura_02' : 'route_chd_mohali_01';
      setState(() {
        _availableRoutes = routes;
        _selectedRouteId ??= routes.any((r) => r.id == preferredRouteId)
            ? preferredRouteId
            : (routes.isNotEmpty ? routes.first.id : 'route_chd_mohali_01');
      });
    }
  }

  List<RetailerShop> get _currentRouteShops {
    if (_selectedRouteId == null) return [];
    return widget.api.retailers.where((r) => r.routeId == _selectedRouteId).toList();
  }

  @override
  void dispose() {
    _gstinCtrl.removeListener(_onGstinChanged);
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _areaCtrl.dispose();
    _landmarkCtrl.dispose();
    _pincodeCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  void _simulateLocationCapture() async {
    double lat;
    double lng;
    double acc = 5.0;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
      lat = pos.latitude;
      lng = pos.longitude;
      acc = pos.accuracy;
    } catch (_) {
      // Fallback to active territory center
      final bool isJodhpur = widget.api.activeTerritory == 'jodhpur';
      lat = isJodhpur
          ? 26.2850 + (DateTime.now().millisecond % 50) * 0.0001
          : 30.7225 + (DateTime.now().millisecond % 50) * 0.0001;
      lng = isJodhpur
          ? 73.0180 + (DateTime.now().millisecond % 50) * 0.0001
          : 76.7620 + (DateTime.now().millisecond % 50) * 0.0001;
      acc = 8.0 + (DateTime.now().second % 6);
    }

    final suggested = await widget.api.suggestNearbyRoute(
      latitude: lat,
      longitude: lng,
      currentRouteId: _selectedRouteId,
    );

    if (mounted) {
      setState(() {
        _latitude = lat;
        _longitude = lng;
        _accuracyMeters = acc;
        _gpsCaptured = true;
        _suggestedNearbyRoute = suggested;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📍 Pin dropped: ${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E (±${acc.round()}m)',
          ),
          backgroundColor: AirbnbTheme.dark,
        ),
      );
    }
  }

  void _openMapPinPicker() async {
    final bool isJodhpur = widget.api.activeTerritory == 'jodhpur';
    final fallbackArea = isJodhpur ? 'Sardarpura, Jodhpur' : 'Sector 17, Chandigarh';

    final result = await MapPinPickerDialog.show(
      context,
      initialLatitude: _latitude ?? widget.api.currentRepLat,
      initialLongitude: _longitude ?? widget.api.currentRepLng,
      shopName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Retailer Shop',
      initialArea: _areaCtrl.text.trim().isNotEmpty ? _areaCtrl.text.trim() : fallbackArea,
    );

    if (result != null && mounted) {
      final suggested = await widget.api.suggestNearbyRoute(
        latitude: result.latitude,
        longitude: result.longitude,
        currentRouteId: _selectedRouteId,
      );

      if (!mounted) return;

      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _accuracyMeters = result.accuracyMeters;
        _gpsCaptured = true;
        _suggestedNearbyRoute = suggested;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📍 Map Pin Set: ${result.latitude.toStringAsFixed(4)}° N, ${result.longitude.toStringAsFixed(4)}° E (±${result.accuracyMeters.round()}m)',
          ),
          backgroundColor: AirbnbTheme.dark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleSave() async {
    final name = _nameCtrl.text.trim();
    final owner = _ownerCtrl.text.trim();
    final rawPhone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      _showError(AppStrings.shopNameRequired);
      return;
    }
    if (owner.isEmpty) {
      _showError(AppStrings.ownerNameRequired);
      return;
    }

    final phoneError = PhoneSanitizer.validateIndianMobile(rawPhone);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    if (!_whatsappSameAsPhone) {
      final wa = _whatsappCtrl.text.trim();
      if (wa.isNotEmpty) {
        final waError = PhoneSanitizer.validateIndianMobile(wa);
        if (waError != null) {
          _showError('WhatsApp: $waError');
          return;
        }
      }
    }

    final bool isJodhpur = widget.api.activeTerritory == 'jodhpur';
    final fallbackArea = isJodhpur ? 'Sardarpura, Jodhpur' : 'Sector 17, Chandigarh';

    // 1. Check for duplicates
    final dupResult = widget.api.checkDuplicateRetailer(
      phone: rawPhone,
      name: name,
      area: _areaCtrl.text.trim().isNotEmpty ? _areaCtrl.text.trim() : fallbackArea,
      gstin: _gstinCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    if (dupResult.hasDuplicate) {
      final proceed = await _showDuplicateWarning(dupResult);
      if (!proceed) return;
    }

    setState(() => _isSaving = true);
    try {
      final newShop = await widget.api.createRetailerDurable(
        name: name,
        ownerName: owner,
        phone: rawPhone,
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : _areaCtrl.text.trim(),
        area: _areaCtrl.text.trim().isNotEmpty ? _areaCtrl.text.trim() : fallbackArea,
        routeId: _selectedRouteId,
        shopType: _selectedShopType,
        gstin: _gstinCtrl.text.trim().isNotEmpty ? _gstinCtrl.text.trim().toUpperCase() : null,
        pincode: _pincodeCtrl.text.trim().isNotEmpty ? _pincodeCtrl.text.trim() : null,
        landmark: _landmarkCtrl.text.trim().isNotEmpty ? _landmarkCtrl.text.trim() : null,
        latitude: _latitude,
        longitude: _longitude,
        locationAccuracyMeters: _accuracyMeters,
        suggestedClass: _selectedClass,
        routeInsertPosition: _routeInsertPosition,
        insertAfterRetailerId: _routeInsertPosition == 'AFTER_SHOP' ? _insertAfterShopId : null,
        whatsappPhone: _whatsappSameAsPhone ? rawPhone : _whatsappCtrl.text.trim(),
        gstType: _gstType,
        panNumber: _panCtrl.text.trim().isNotEmpty ? _panCtrl.text.trim().toUpperCase() : null,
      );

      widget.onShopAdded?.call();
      if (mounted) {
        Navigator.pop(context, newShop);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ "${newShop.name}" ($_selectedClassBadge) ${AppStrings.savedOnPhone}'),
            backgroundColor: AirbnbTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Error saving shop: $e');
      }
    }
  }

  Widget _buildClassTile({
    required String keyId,
    required String classCode,
    required String title,
    required String subtitle,
    required String credit,
    required Color color,
    required IconData icon,
  }) {
    final isSel = _selectedClass == classCode;
    return Expanded(
      child: InkWell(
        key: ValueKey(keyId),
        onTap: () => setState(() => _selectedClass = classCode),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? color : AirbnbTheme.border,
              width: isSel ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: isSel ? color : AirbnbTheme.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isSel ? color : AirbnbTheme.dark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSel ? color.withValues(alpha: 0.9) : AirbnbTheme.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSel ? color : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  credit,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isSel ? Colors.white : AirbnbTheme.dark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<bool> _showDuplicateWarning(DuplicateCheckResult dup) async {
    final isStrict = dup.requiresStrictConfirmation;
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: !isStrict,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isStrict ? Icons.error_outline : Icons.warning_amber_rounded,
              color: isStrict ? Colors.red.shade700 : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isStrict ? 'Exact Match Detected' : AppStrings.duplicateWarningTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isStrict ? Colors.red.shade800 : AirbnbTheme.dark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isStrict)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.gpp_bad, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Exact match on Mobile or GSTIN. Proceeding will create a duplicate ledger entry.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            Text(dup.message ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            if (dup.matchedShop != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AirbnbTheme.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AirbnbTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dup.matchedShop!.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    Text(
                      '${dup.matchedShop!.ownerName} • ${dup.matchedShop!.phone}',
                      style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                    ),
                    Text(
                      dup.matchedShop!.area,
                      style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              // Pop the sheet and select existing shop
              Navigator.pop(context, dup.matchedShop);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbTheme.coral,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.openExistingShop, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: isStrict ? Colors.red.shade700 : AirbnbTheme.grey,
            ),
            child: Text(
              isStrict ? 'I Confirm Separate Shop' : AppStrings.differentShopConfirm,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AirbnbTheme.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.addShopTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.quickAddSubtitle,
                      style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _selectedClassColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _selectedClassColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _selectedClassBadge,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _selectedClassColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Shop Name
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: AppStrings.shopNameLabel,
                hintText: AppStrings.shopNameHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Owner Name
            TextField(
              controller: _ownerCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: AppStrings.ownerNameLabel,
                hintText: AppStrings.ownerNameHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),

            // 3. Mobile Number
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: AppStrings.mobileLabel,
                prefixText: '+91 ',
                hintText: AppStrings.mobileHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),

            // WhatsApp Toggle
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _whatsappSameAsPhone,
                    activeColor: const Color(0xFF25D366),
                    onChanged: (v) => setState(() => _whatsappSameAsPhone = v ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _whatsappSameAsPhone = !_whatsappSameAsPhone),
                    child: const Text(
                      'WhatsApp same as calling mobile',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AirbnbTheme.dark),
                    ),
                  ),
                ),
              ],
            ),
            if (!_whatsappSameAsPhone) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _whatsappCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'WhatsApp Number',
                  prefixText: '+91 ',
                  prefixIcon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Shop Classification & Category Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shop Class & Category',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _selectedClassColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _selectedClassColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _selectedClassBadge,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _selectedClassColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select outlet classification and primary retail category:',
              style: TextStyle(fontSize: 11, color: AirbnbTheme.grey),
            ),
            const SizedBox(height: 8),

            // Class Cards: Class A, Class B, Class C
            Row(
              children: [
                _buildClassTile(
                  keyId: 'class_a_tile',
                  classCode: 'CLASS_A',
                  title: 'Class A',
                  subtitle: 'Super Mart',
                  credit: '₹1,00,000 Limit',
                  color: const Color(0xFFD97706),
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(width: 8),
                _buildClassTile(
                  keyId: 'class_b_tile',
                  classCode: 'CLASS_B',
                  title: 'Class B',
                  subtitle: 'Kirana Store',
                  credit: '₹50,000 Limit',
                  color: const Color(0xFF1A73E8),
                  icon: Icons.local_grocery_store_rounded,
                ),
                const SizedBox(width: 8),
                _buildClassTile(
                  keyId: 'class_c_tile',
                  classCode: 'CLASS_C',
                  title: 'Class C',
                  subtitle: 'Small Kiosk',
                  credit: '₹15,000 / Cash',
                  color: const Color(0xFF00B894),
                  icon: Icons.shopping_bag_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Category Chips with emojis
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _shopCategories.map((cat) {
                final String type = cat['type'] as String;
                final String label = cat['label'] as String;
                final String emoji = cat['emoji'] as String;
                final String recClass = cat['recommendedClass'] as String;
                final isSel = _selectedShopType == type;

                return ChoiceChip(
                  label: Text(
                    '$emoji $label',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? Colors.white : AirbnbTheme.dark,
                    ),
                  ),
                  selected: isSel,
                  selectedColor: AirbnbTheme.dark,
                  backgroundColor: AirbnbTheme.lightGrey,
                  side: BorderSide(
                    color: isSel ? AirbnbTheme.dark : AirbnbTheme.border,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedShopType = type;
                      _selectedClass = recClass;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // 4. Rapido-Style Location Picker & Geotag
            if (!_gpsCaptured)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: _openMapPinPicker,
                      icon: const Icon(Icons.pin_drop_rounded, size: 18, color: AirbnbTheme.coral),
                      label: const Text(
                        'Set on Map 🗺️',
                        style: TextStyle(color: AirbnbTheme.coral, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: const BorderSide(color: AirbnbTheme.coral, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _simulateLocationCapture,
                      icon: const Icon(Icons.my_location, size: 16, color: AirbnbTheme.dark),
                      label: Text(
                        AppStrings.captureGpsButton,
                        style: const TextStyle(color: AirbnbTheme.dark, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: const BorderSide(color: AirbnbTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF008A05).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF008A05).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF008A05), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Shop GPS Pin Dropped',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF008A05)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF008A05).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '±${_accuracyMeters?.round() ?? 5}m',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF008A05)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_latitude!.toStringAsFixed(5)}° N, ${_longitude!.toStringAsFixed(5)}° E',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.dark),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        InkWell(
                          onTap: _openMapPinPicker,
                          child: Row(
                            children: const [
                              Icon(Icons.edit_location_alt_rounded, size: 14, color: AirbnbTheme.jodhpurBlue),
                              SizedBox(width: 4),
                              Text('Adjust Pin on Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _simulateLocationCapture,
                          child: Row(
                            children: const [
                              Icon(Icons.refresh, size: 14, color: AirbnbTheme.grey),
                              SizedBox(width: 4),
                              Text('Recalibrate GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // Route / Beat Picker
            if (_availableRoutes.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedRouteId,
                decoration: InputDecoration(
                  labelText: AppStrings.routeLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: _availableRoutes.map((r) {
                  return DropdownMenuItem<String>(
                    value: r.id,
                    child: Text(
                      '${r.name} (${r.code})',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRouteId = val);
                },
              ),
              const SizedBox(height: 8),

              // Route Stop Insert Position Selector
              Row(
                children: [
                  const Text('Insert in Route: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _routeInsertPosition,
                      isDense: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'AT_END', child: Text('At End of Route', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'AT_START', child: Text('At Start of Route', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'AFTER_SHOP', child: Text('After Specific Shop...', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _routeInsertPosition = val);
                      },
                    ),
                  ),
                ],
              ),
              if (_routeInsertPosition == 'AFTER_SHOP') ...[
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _insertAfterShopId,
                  decoration: InputDecoration(
                    labelText: 'Select Preceding Shop',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _currentRouteShops.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.name} (${s.area})',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _insertAfterShopId = val),
                ),
              ],
              const SizedBox(height: 8),
            ],

            // Nearby Beat Suggestion Pill (Non-intrusive suggestion only)
            if (_suggestedNearbyRoute != null && _suggestedNearbyRoute!.id != _selectedRouteId) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.near_me, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nearby beat suggestion: ${_suggestedNearbyRoute!.name}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() => _selectedRouteId = _suggestedNearbyRoute!.id);
                      },
                      child: const Text('Switch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Collapsible More Details
            InkWell(
              onTap: () => setState(() => _showMoreDetails = !_showMoreDetails),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      AppStrings.moreDetails,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue),
                    ),
                    Icon(
                      _showMoreDetails ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AirbnbTheme.jodhpurBlue,
                    ),
                  ],
                ),
              ),
            ),

            if (_showMoreDetails) ...[
              const SizedBox(height: 8),

              // GST Registration Status & PAN
              const Text('GST Registration Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: Text('Consumer / Unregistered', style: TextStyle(fontSize: 10, color: _gstType == 'CONSUMER' ? Colors.white : AirbnbTheme.dark)),
                    selected: _gstType == 'CONSUMER',
                    selectedColor: AirbnbTheme.dark,
                    onSelected: (_) => setState(() => _gstType = 'CONSUMER'),
                  ),
                  ChoiceChip(
                    label: Text('Composition Scheme', style: TextStyle(fontSize: 10, color: _gstType == 'COMPOSITION' ? Colors.white : AirbnbTheme.dark)),
                    selected: _gstType == 'COMPOSITION',
                    selectedColor: AirbnbTheme.dark,
                    onSelected: (_) => setState(() => _gstType = 'COMPOSITION'),
                  ),
                  ChoiceChip(
                    label: Text('Regular (B2B Tax Invoice)', style: TextStyle(fontSize: 10, color: _gstType == 'REGULAR' ? Colors.white : AirbnbTheme.dark)),
                    selected: _gstType == 'REGULAR',
                    selectedColor: AirbnbTheme.dark,
                    onSelected: (_) => setState(() => _gstType = 'REGULAR'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _gstinCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: InputDecoration(
                        labelText: AppStrings.gstinLabel,
                        hintText: '15-char GSTIN',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _panCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'PAN Number',
                        hintText: '10-char PAN',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _addressCtrl,
                decoration: InputDecoration(
                  labelText: AppStrings.addressLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _areaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Area / Locality',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _pincodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppStrings.pincodeLabel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _landmarkCtrl,
                decoration: InputDecoration(
                  labelText: AppStrings.landmarkLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Big Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbTheme.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(AppStrings.saveShopButton, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
