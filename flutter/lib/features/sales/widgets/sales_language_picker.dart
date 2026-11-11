import 'package:flutter/material.dart';
import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/language_controller.dart';
import '../../../theme/airbnb_theme.dart';

/// Modal bottom sheet or embedded selector for choosing application language.
/// Provides 4 large touch buttons (>= 48dp) displaying each language's native name:
/// English, Hinglish, हिन्दी, ગુજરાતી.
class SalesLanguagePicker extends StatelessWidget {
  final VoidCallback? onLanguageChanged;
  final bool isDismissible;

  const SalesLanguagePicker({
    super.key,
    this.onLanguageChanged,
    this.isDismissible = true,
  });

  /// Opens the language picker as a modal bottom sheet.
  static Future<void> showSheet(BuildContext context, {bool isDismissible = true}) {
    return showModalBottomSheet(
      context: context,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SalesLanguagePicker(
        isDismissible: isDismissible,
        onLanguageChanged: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.of(context);
    final current = controller.currentLanguage;
    final strings = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AirbnbTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Row(
              children: [
                const Icon(Icons.language, color: AirbnbTheme.coral, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.t('choose_language'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AirbnbTheme.dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.t('choose_language_subtitle'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AirbnbTheme.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDismissible)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // 4 Big Language Selection Buttons (Minimum height 52dp)
            ...AppLanguage.values.map((lang) {
              final isSelected = lang == current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () async {
                    await controller.setLanguage(lang);
                    onLanguageChanged?.call();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AirbnbTheme.coral.withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AirbnbTheme.coral : AirbnbTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AirbnbTheme.coral : AirbnbTheme.grey,
                              width: 2,
                            ),
                            color: isSelected ? AirbnbTheme.coral : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.nativeName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? AirbnbTheme.coral : AirbnbTheme.dark,
                                  height: lang.lineHeight,
                                ),
                              ),
                              Text(
                                lang.englishName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? AirbnbTheme.coral : AirbnbTheme.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Small top-app-bar action button with a globe icon for one-tap language switching.
class SalesLanguageSwitchAction extends StatelessWidget {
  const SalesLanguageSwitchAction({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.of(context);
    final current = controller.currentLanguage;

    return InkWell(
      onTap: () => SalesLanguagePicker.showSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AirbnbTheme.lightGrey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AirbnbTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 16, color: AirbnbTheme.dark),
            const SizedBox(width: 4),
            Text(
              current.nativeName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AirbnbTheme.dark,
                height: current.lineHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
