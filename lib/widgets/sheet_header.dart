import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one header every bottom sheet uses: a serif title on the sheet's left
/// edge, the same treatment as the dose sheet's "Select Strain", with an
/// optional leading mark and trailing action (a close or edit button, 48dp).
///
/// Sheets carry no drag handle: the dose sheet has none, and one sheet with a
/// handle beside four without reads as two systems.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleColor,
  });

  final String title;

  /// A quiet line under the title (a strain's full name, a date).
  final String? subtitle;

  /// Optional identity mark before the title (a strain's mark), top-aligned.
  final Widget? leading;

  final Widget? trailing;

  /// Title ink. Defaults to `textPrimary`; a strain sheet passes the strain's
  /// legible colour so its code reads as identity, as it does everywhere else.
  final Color? titleColor;

  /// Horizontal inset of sheet content, so bodies align to the title.
  static const double inset = 20;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 18, trailing == null ? inset : 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Padding(padding: const EdgeInsets.only(top: 4), child: leading),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppType.display(size: 30, color: titleColor ?? c.textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: AppType.sans,
                      fontSize: 14,
                      height: 1.3,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Opens [child] as a modal sheet on the theme's sheet surface
/// (`surfaceRaised`, 24dp top radius). Use this instead of passing a
/// transparent background, which leaves forms floating over the screen.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: builder,
    );

/// Quiet sentence-case group label for sheets and settings ("Dose size").
/// Tracked caps are reserved for the Stats section heads.
TextStyle sectionLabelStyle(BuildContext context) => TextStyle(
      fontFamily: AppType.sans,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: context.c.textTertiary,
    );
