import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/local/app_database.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';

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
  final _addressCtrl = TextEditingController();
  final _areaCtrl = TextEditingController(text: 'Sardarpura');
  final _landmarkCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();

  String? _selectedRouteId;
  List<RouteEntry> _availableRoutes = [];
  RouteEntry? _suggestedNearbyRoute;
  String _selectedShopType = 'KIRANA';
  final String _suggestedClass = 'NEW';
  bool _showMoreDetails = false;
  bool _isSaving = false;

  double? _latitude;
  double? _longitude;
  double? _accuracyMeters;
  bool _gpsCaptured = false;

  final List<String> _shopTypes = [
    'KIRANA',
    'GENERAL_STORE',
    'SUPERMARKET',
    'PHARMACY',
    'PAAN_TEA_STALL',
    'DHABA_RESTAURANT',
    'WHOLESALE',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _selectedRouteId = widget.defaultRouteId;
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final routes = await widget.api.getAvailableRoutes();
    if (mounted) {
      setState(() {
        _availableRoutes = routes;
        _selectedRouteId ??= routes.isNotEmpty ? routes.first.id : 'route_sojati_01';
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _areaCtrl.dispose();
    _landmarkCtrl.dispose();
    _pincodeCtrl.dispose();
    _gstinCtrl.dispose();
    super.dispose();
  }

  void _simulateLocationCapture() async {
    // Captures realistic coordinates with accuracy
    final lat = 26.2850 + (DateTime.now().millisecond % 100) * 0.0001;
    final lng = 73.0180 + (DateTime.now().millisecond % 100) * 0.0001;
    final acc = 8.0 + (DateTime.now().second % 10);

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
            '📍 ${AppStrings.locationAccuracy(_accuracyMeters!)}',
          ),
          backgroundColor: AirbnbTheme.dark,
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
    final cleanDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length < 10) {
      _showError(AppStrings.validMobileRequired);
      return;
    }

    // 1. Check for duplicates
    final dupResult = widget.api.checkDuplicateRetailer(
      phone: rawPhone,
      name: name,
      area: _areaCtrl.text.trim().isNotEmpty ? _areaCtrl.text.trim() : 'Jodhpur',
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
        area: _areaCtrl.text.trim().isNotEmpty ? _areaCtrl.text.trim() : 'Jodhpur',
        routeId: _selectedRouteId,
        shopType: _selectedShopType,
        gstin: _gstinCtrl.text.trim().isNotEmpty ? _gstinCtrl.text.trim() : null,
        pincode: _pincodeCtrl.text.trim().isNotEmpty ? _pincodeCtrl.text.trim() : null,
        landmark: _landmarkCtrl.text.trim().isNotEmpty ? _landmarkCtrl.text.trim() : null,
        latitude: _latitude,
        longitude: _longitude,
        locationAccuracyMeters: _accuracyMeters,
        suggestedClass: _suggestedClass,
      );

      widget.onShopAdded?.call();
      if (mounted) {
        Navigator.pop(context, newShop);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ "${newShop.name}" ${AppStrings.savedOnPhone}'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Class: NEW (Cash Only)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
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
            const SizedBox(height: 10),

            // 4. Location Geotag Button
            OutlinedButton.icon(
              onPressed: _simulateLocationCapture,
              icon: Icon(
                _gpsCaptured ? Icons.check_circle : Icons.my_location,
                size: 18,
                color: _gpsCaptured ? AirbnbTheme.success : AirbnbTheme.coral,
              ),
              label: Text(
                _gpsCaptured
                    ? '📍 ${AppStrings.locationAccuracy(_accuracyMeters!)}'
                    : AppStrings.captureGpsButton,
                style: TextStyle(
                  color: _gpsCaptured ? AirbnbTheme.success : AirbnbTheme.coral,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(color: _gpsCaptured ? AirbnbTheme.success : AirbnbTheme.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),

            // Route / Beat Picker
            if (_availableRoutes.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedRouteId,
                decoration: InputDecoration(
                  labelText: AppStrings.routeLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: _availableRoutes.map((r) {
                  return DropdownMenuItem<String>(
                    value: r.id,
                    child: Text('${r.name} (${r.code})', style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRouteId = val);
                },
              ),
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
              // Shop Type Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _shopTypes.map((type) {
                  final isSel = _selectedShopType == type;
                  final label = type.replaceAll('_', ' ');
                  return ChoiceChip(
                    label: Text(label, style: TextStyle(fontSize: 10, color: isSel ? Colors.white : AirbnbTheme.dark)),
                    selected: isSel,
                    selectedColor: AirbnbTheme.dark,
                    onSelected: (_) => setState(() => _selectedShopType = type),
                  );
                }).toList(),
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
              const SizedBox(height: 8),
              TextField(
                controller: _gstinCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: AppStrings.gstinLabel,
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
