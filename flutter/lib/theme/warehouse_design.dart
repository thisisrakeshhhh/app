import 'package:flutter/material.dart';

/// Shared design tokens and clean, high-contrast UI primitives for the
/// Routidrow Warehouse / Inventory module.
class WarehouseDesign {
  WarehouseDesign._();

  // Semantic Color Palette
  static const Color navy = Color(0xFF0F172A);
  static const Color navySlate = Color(0xFF1E293B);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color blueBorder = Color(0xFFBFDBFE);

  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFFECFDF5);
  static const Color greenBorder = Color(0xFFA7F3D0);

  static const Color amber = Color(0xFFD97706);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color amberBorder = Color(0xFFFDE68A);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color redBorder = Color(0xFFFECACA);

  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);

  // Spacing & Radius Scale
  static const double padScreen = 16.0;
  static const double padCard = 14.0;
  static const double radiusCard = 14.0;
  static const double radiusPill = 8.0;
  static const double buttonHeight = 44.0;

  static BoxDecoration cardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radiusCard),
      border: Border.all(color: borderColor ?? border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

/// Compact semantic status pill used across all four warehouse screens.
class WarehouseStatusPill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final Color borderColor;
  final IconData? icon;

  const WarehouseStatusPill({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
    required this.borderColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(WarehouseDesign.radiusPill),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
