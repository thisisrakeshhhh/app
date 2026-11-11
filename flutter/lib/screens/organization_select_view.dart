import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/airbnb_theme.dart';

class OrganizationSelectSheet extends StatefulWidget {
  final AuthService authService;

  const OrganizationSelectSheet({
    super.key,
    required this.authService,
  });

  static Future<void> show(BuildContext context, AuthService authService) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrganizationSelectSheet(authService: authService),
    );
  }

  @override
  State<OrganizationSelectSheet> createState() => _OrganizationSelectSheetState();
}

class _OrganizationSelectSheetState extends State<OrganizationSelectSheet> {
  bool _isSwitching = false;
  String? _errorMessage;

  Future<void> _switchOrg(String targetOrgId) async {
    if (widget.authService.session?.activeOrganizationId == targetOrgId) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSwitching = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.switchOrganization(targetOrgId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSwitching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.authService.session;
    final organizations = session?.organizations ?? [];
    final activeOrgId = session?.activeOrganizationId ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Distributor Organizations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AirbnbTheme.dark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select an authorized FMCG distributor tenant for your session',
            style: TextStyle(fontSize: 12, color: AirbnbTheme.grey),
          ),
          const SizedBox(height: 16),

          // Error banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD2D2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AirbnbTheme.coral, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFC01E2E), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Organizations list
          if (organizations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'No organizations associated with this account.',
                  style: TextStyle(color: AirbnbTheme.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: organizations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final org = organizations[index];
                final isActive = org.id == activeOrgId;

                return InkWell(
                  onTap: _isSwitching ? null : () => _switchOrg(org.id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive ? AirbnbTheme.lightGrey : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive ? AirbnbTheme.coral : AirbnbTheme.border,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AirbnbTheme.coral.withAlpha(25)
                                : AirbnbTheme.lightGrey,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.business,
                            color: isActive ? AirbnbTheme.coral : AirbnbTheme.dark,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                org.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AirbnbTheme.dark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    org.id,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AirbnbTheme.grey,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AirbnbTheme.jodhpurBlue.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      org.role,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AirbnbTheme.jodhpurBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (_isSwitching && isActive)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (isActive)
                          const Icon(Icons.check_circle, color: AirbnbTheme.coral, size: 22)
                        else
                          Tooltip(
                            message: 'Tenant switching deferred to Phase B2.2',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AirbnbTheme.lightGrey,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AirbnbTheme.border),
                                  ),
                                  child: const Text(
                                    'B2.2 Scope',
                                    style: TextStyle(fontSize: 10, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.lock_outline, color: AirbnbTheme.grey, size: 18),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Logout button
          OutlinedButton.icon(
            onPressed: _isSwitching
                ? null
                : () async {
                    Navigator.pop(context);
                    await widget.authService.logout();
                  },
            icon: const Icon(Icons.logout, size: 16, color: AirbnbTheme.coral),
            label: const Text('Sign Out', style: TextStyle(color: AirbnbTheme.coral)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AirbnbTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }
}
