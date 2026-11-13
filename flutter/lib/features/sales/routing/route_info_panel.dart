import 'package:flutter/material.dart';
import 'package:lala_distributor/theme/airbnb_theme.dart';
import 'route_models.dart';

/// Compact, single-hand usable FMCG route intelligence card.
/// Answers:
/// 1. Where do I go next?
/// 2. How far is it and how long will it take?
/// 3. How much of today's beat remains?
class RouteInfoPanel extends StatelessWidget {
  final BeatRoutePlan? plan;
  final bool isCalculating;
  final VoidCallback onNavigatePressed;

  const RouteInfoPanel({
    super.key,
    required this.plan,
    required this.isCalculating,
    required this.onNavigatePressed,
  });

  @override
  Widget build(BuildContext context) {
    if (plan == null) return const SizedBox.shrink();

    final activeLeg = plan!.activeLeg;
    final hasActiveLeg = activeLeg != null;
    final remainingStops = plan!.totalStops - plan!.completedStops;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AirbnbTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: Next Stop badge + Status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.near_me_rounded, size: 12, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text(
                      'NEXT STOP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isCalculating)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AirbnbTheme.coral),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Calculating road...',
                      style: TextStyle(fontSize: 10, color: AirbnbTheme.grey),
                    ),
                  ],
                )
              else if (activeLeg?.isApproximate == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Offline Estimate',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                )
              else if (activeLeg?.status == RouteLegStatus.cached)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Cached Road',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF00B894)),
                  ),
                )
              else if (activeLeg?.status == RouteLegStatus.success)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Live Road',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF1A73E8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Next Shop Name & ETA Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasActiveLeg
                          ? activeLeg.destinationName
                          : (remainingStops > 0 ? 'No Route Available' : 'Beat Completed'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AirbnbTheme.dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (hasActiveLeg)
                      Row(
                        children: [
                          Text(
                            activeLeg.formattedDistance,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                          const Text(' • ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(
                            activeLeg.formattedDuration,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        remainingStops > 0 ? 'Locations missing or routing unavailable' : 'All assigned shops visited!',
                        style: TextStyle(
                          fontSize: 12,
                          color: remainingStops > 0 ? AirbnbTheme.grey : const Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              // Action button: Navigate in Google Maps
              if (hasActiveLeg)
                ElevatedButton.icon(
                  onPressed: onNavigatePressed,
                  icon: const Icon(Icons.navigation_rounded, size: 15),
                  label: const Text('Navigate', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          const Divider(height: 1, thickness: 0.8, color: AirbnbTheme.border),
          const SizedBox(height: 6),

          // Footer summary: Remaining route overview
          Row(
            children: [
              const Icon(Icons.route_outlined, size: 13, color: AirbnbTheme.grey),
              const SizedBox(width: 4),
              Text(
                'Today: $remainingStops of ${plan!.totalStops} stops left',
                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${plan!.formattedRemainingDistance} • ${plan!.formattedRemainingDuration}',
                style: const TextStyle(fontSize: 11, color: AirbnbTheme.dark, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
