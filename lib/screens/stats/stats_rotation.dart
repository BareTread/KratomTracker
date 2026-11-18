import 'package:flutter/material.dart';

import '../../domain/analytics_service.dart';
import '../../models/strain.dart';
import '../../theme/app_theme.dart';
import '../../widgets/strain_mark.dart';
import 'stats_common.dart';

/// Thirty strains in a list is a list, not an answer. Eight rows plus a
/// folded tail shows what he actually leans on, and the caption says out loud
/// when one of them has stopped being part of a rotation.
class RotationSection extends StatelessWidget {
  const RotationSection({
    super.key,
    required this.rotation,
    required this.strainsById,
  });

  final RotationSummary rotation;
  final Map<String, Strain> strainsById;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotationCaption(rotation, strainsById),
          style: quietStyle(context).copyWith(
            color: rotation.concentrated ? c.caution : c.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        // Names the trailing column once instead of stamping "days" on every
        // row — the 17d figures sit directly under it.
        Row(
          children: [
            const Spacer(),
            for (final (label, width) in const [('share', 40.0), ('days', 42.0)])
              SizedBox(
                width: width,
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in rotation.rows)
          _RotationRow(
            share: row,
            strain: row.strainId == null ? null : strainsById[row.strainId],
          ),
      ],
    );
  }
}

String rotationCaption(
  RotationSummary rotation,
  Map<String, Strain> strainsById,
) {
  if (rotation.rows.isEmpty) return 'No strain usage in this range yet.';
  final top = rotation.rows.first;
  final name = strainsById[top.strainId]?.code ?? 'One strain';
  final share = (top.share * 100).round();
  if (rotation.concentrated) {
    return '$name is $share% of everything here — that is leaning, '
        'not rotating.';
  }
  final strains = rotation.strainCount == 1 ? 'strain' : 'strains';
  return '${rotation.strainCount} $strains, '
      'the heaviest at $share% — a real rotation.';
}

class _RotationRow extends StatelessWidget {
  const _RotationRow({
    required this.share,
    required this.strain,
  });

  final StrainShare share;
  final Strain? strain;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final folded = share.strainId == null;
    final color = strain == null
        ? c.textTertiary
        : legibleStrainColor(
            Color(strain!.color),
            Theme.of(context).brightness,
          );
    final label = folded
        ? 'Other'
        : (strain?.code.isNotEmpty ?? false)
            ? strain!.code
            : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Row(
              children: [
                // Shape carries identity where colour cannot: two red
                // strains stay distinct by mark + code.
                if (strain != null && !folded) ...[
                  StrainMark(
                    shape: resolveLeafShape(strain!.icon, strain!.code),
                    color: color,
                    size: 14,
                  ),
                  const SizedBox(width: 7),
                ] else
                  const SizedBox(width: 21),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      height: 1.1,
                      fontWeight:
                          folded ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 5),
              // A 21% share fills 21% of the track. The old version scaled
              // bars to the heaviest strain, so 19–21% all drew full.
              painter: ShareBarPainter(
                share: share.share,
                fill: color,
                track: c.hairline,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${(share.share * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.5,
                height: 1.1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              // Days used, not doses: a strain on 24 of 30 days is not being
              // rested whatever the gram total says.
              '${share.daysUsed}d',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 12.5,
                height: 1.1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Public so tests can read the fraction off the widget: the share is the
/// whole contract of this bar.
class ShareBarPainter extends CustomPainter {
  const ShareBarPainter({
    required this.share,
    required this.fill,
    required this.track,
  });

  final double share;
  final Color fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final inset = size.height / 2;
    final span = size.width - inset * 2;
    if (span <= 0) return;

    canvas.drawLine(
      Offset(inset, y),
      Offset(size.width - inset, y),
      Paint()
        ..color = track
        ..strokeWidth = size.height
        ..strokeCap = StrokeCap.round,
    );
    final width = span * share.clamp(0.0, 1.0);
    if (width <= 0) return;
    canvas.drawLine(
      Offset(inset, y),
      Offset(inset + width, y),
      Paint()
        ..color = fill.withValues(alpha: 0.85)
        ..strokeWidth = size.height
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant ShareBarPainter old) =>
      old.share != share || old.fill != fill || old.track != track;
}
