import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/dosage.dart';
import '../../models/strain.dart';
import '../../theme/app_theme.dart';
import '../../widgets/strain_mark.dart';
import '../../widgets/vine_painter.dart';
import 'home_dose_actions.dart';

const _tabular = [FontFeature.tabularFigures()];

/// The day's doses as leaves on a single vine. Three fixed columns:
/// time gutter (64) · vine band (~72) · content. Only the vine itself curves.
///
/// On low-dose days the vertical rhythm expands (via [VineRhythm]) so the
/// ledger occupies the available viewport instead of clustering at the top.
class HomeDosageList extends StatelessWidget {
  const HomeDosageList({
    super.key,
    required this.dosages,
    required this.strainsById,
    this.isToday = true,
    this.header = const SizedBox.shrink(),
  });

  final List<Dosage> dosages;
  final Map<String, Strain> strainsById;

  /// When true, the vine continues past the last dose to a terminal NOW node.
  final bool isToday;

  /// Optional widget rendered above the vine (kept for call-site compatibility).
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final sorted = [...dosages]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Build the flat item list: optional header, then dose rows interleaved
    // with gap strips, then the NOW node on today (or a trailing stem end).
    final items = <_VineItem>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0) {
        items.add(
          _VineItem.gap(
            sorted[i].timestamp.difference(sorted[i - 1].timestamp),
            fromIndex: i - 1,
            toIndex: i,
          ),
        );
      }
      items.add(_VineItem.dose(sorted[i], nodeIndex: i));
    }
    if (isToday) {
      final last = sorted.isEmpty ? null : sorted.last;
      final since = last == null
          ? Duration.zero
          : DateTime.now().difference(last.timestamp);
      if (sorted.isNotEmpty) {
        items.add(
          _VineItem.gap(
            since,
            fromIndex: sorted.length - 1,
            toIndex: sorted.length,
            toNow: true,
          ),
        );
      }
      items.add(
        _VineItem.now(
          nodeIndex: sorted.length,
          lastColor: last == null
              ? null
              : _strainColor(context, strainsById[last.strainId]),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rhythm = VineRhythm.compute(
          viewportHeight: constraints.maxHeight,
          doseCount: sorted.length,
          showNow: isToday,
        );

        return ListView.builder(
          // Bottom pad clears the circular FAB floating above the nav.
          padding: const EdgeInsets.only(
            top: VineRhythm.listTopPad,
            bottom: VineRhythm.listBottomPad,
          ),
          itemCount: 1 + items.length,
          itemBuilder: (context, index) {
            if (index == 0) return header;
            final item = items[index - 1];
            return switch (item.kind) {
              _Kind.dose => _DoseRow(
                dosage: item.dosage!,
                strain: strainsById[item.dosage!.strainId],
                nodeIndex: item.nodeIndex,
                rowPitch: rhythm.rowPitch,
                prevColor: item.nodeIndex > 0
                    ? _strainColor(
                        context,
                        strainsById[sorted[item.nodeIndex - 1].strainId],
                      )
                    : null,
                nextColor: item.nodeIndex < sorted.length - 1
                    ? _strainColor(
                        context,
                        strainsById[sorted[item.nodeIndex + 1].strainId],
                      )
                    : (isToday ? _nowColor(context) : null),
                isFirst: item.nodeIndex == 0,
                isLast: item.nodeIndex == sorted.length - 1 && !isToday,
              ),
              _Kind.gap => _GapRow(
                gap: item.gap!,
                gapStrip: rhythm.gapStrip,
                fromIndex: item.fromIndex,
                toIndex: item.toIndex,
                fromColor: _strainColor(
                  context,
                  strainsById[sorted[item.fromIndex].strainId],
                ),
                toColor: item.toNow
                    ? _nowColor(context)
                    : _strainColor(
                        context,
                        strainsById[sorted[item.toIndex].strainId],
                      ),
                toNow: item.toNow,
              ),
              _Kind.now => _NowRow(
                nodeIndex: item.nodeIndex,
                nowPitch: rhythm.nowPitch,
                lastColor: item.lastColor,
              ),
            };
          },
        );
      },
    );
  }

  static Color _strainColor(BuildContext context, Strain? strain) {
    if (strain == null) return context.c.textTertiary;
    return legibleStrainColor(
      Color(strain.color),
      Theme.of(context).brightness,
    );
  }

  static Color _nowColor(BuildContext context) => context.c.textSecondary;
}

enum _Kind { dose, gap, now }

class _VineItem {
  const _VineItem._({
    required this.kind,
    this.dosage,
    this.gap,
    this.nodeIndex = 0,
    this.fromIndex = 0,
    this.toIndex = 0,
    this.toNow = false,
    this.lastColor,
  });

  factory _VineItem.dose(Dosage d, {required int nodeIndex}) =>
      _VineItem._(kind: _Kind.dose, dosage: d, nodeIndex: nodeIndex);

  factory _VineItem.gap(
    Duration gap, {
    required int fromIndex,
    required int toIndex,
    bool toNow = false,
  }) => _VineItem._(
    kind: _Kind.gap,
    gap: gap,
    fromIndex: fromIndex,
    toIndex: toIndex,
    toNow: toNow,
  );

  factory _VineItem.now({required int nodeIndex, Color? lastColor}) =>
      _VineItem._(kind: _Kind.now, nodeIndex: nodeIndex, lastColor: lastColor);

  final _Kind kind;
  final Dosage? dosage;
  final Duration? gap;
  final int nodeIndex;
  final int fromIndex;
  final int toIndex;
  final bool toNow;
  final Color? lastColor;
}

// ── Dose row ──────────────────────────────────────────────────────────────

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.dosage,
    required this.strain,
    required this.nodeIndex,
    required this.rowPitch,
    required this.prevColor,
    required this.nextColor,
    required this.isFirst,
    required this.isLast,
  });

  final Dosage dosage;
  final Strain? strain;
  final int nodeIndex;
  final double rowPitch;
  final Color? prevColor;
  final Color? nextColor;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final rawColor = strain == null
        ? context.c.textTertiary
        : Color(strain!.color);
    final leafColor = legibleStrainColor(rawColor, brightness);
    final amountColor = leafColor;
    final code = strain?.code ?? '???';
    final shape = resolveLeafShape(strain?.icon ?? '', strain?.code ?? '');
    final xOff = VineGeometry.offsetFor(nodeIndex);

    final hour = DateFormat('h:mm').format(dosage.timestamp);
    final ampm = DateFormat('a').format(dosage.timestamp).toUpperCase();

    final semantics =
        '$hour $ampm, $code, ${dosage.amount} grams';

    // Stem colour above/below the leaf so segments join with neighbours.
    final above = prevColor ?? leafColor;
    final below = nextColor ?? leafColor;

    return Semantics(
      button: true,
      label: semantics,
      child: SizedBox(
        height: rowPitch,
        child: InkWell(
          onTap: () => showDosageOptions(context, dosage),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            showDosageOptions(context, dosage);
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Time gutter — right-aligned, fixed 64px.
              SizedBox(
                width: VineGeometry.timeGutter,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hour,
                        style: TextStyle(
                          color: context.c.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                          fontFeatures: _tabular,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ampm,
                        style: TextStyle(
                          color: context.c.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                          letterSpacing: 0.6, // ~0.06em at 10px
                          fontFeatures: _tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Vine band — stem runs beside the leaf; petiole attaches.
              SizedBox(
                width: VineGeometry.vineBand,
                height: rowPitch,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size(VineGeometry.vineBand, rowPitch),
                      painter: VineRowStemPainter(
                        xOffset: xOff,
                        colorAbove: above,
                        colorMid: leafColor,
                        colorBelow: below,
                        extendUp: !isFirst,
                        extendDown: !isLast,
                      ),
                    ),
                    // Leaf stays band-centred so data columns remain stable.
                    // The stem is offset beside it (see VineGeometry.offsetFor).
                    Align(
                      alignment: Alignment.center,
                      child: StrainMark(
                        shape: shape,
                        color: leafColor,
                        size: VineGeometry.leafSize,
                      ),
                    ),
                  ],
                ),
              ),
              // Content — ledger line: identity left, amount on the right
              // margin so the row spans the full width and the amounts form
              // one scannable right-aligned column.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  child: Row(
                    // Code and amount share a baseline so the row reads as
                    // one line across the width rather than two blocks at
                    // different heights.
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              code,
                              style: TextStyle(
                                color: context.c.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatAmount(dosage.amount),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: amountColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                          letterSpacing: -0.3,
                          fontFeatures: _tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    final body = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    return '${body}g';
  }
}

// ── Gap strip ─────────────────────────────────────────────────────────────

class _GapRow extends StatelessWidget {
  const _GapRow({
    required this.gap,
    required this.gapStrip,
    required this.fromIndex,
    required this.toIndex,
    required this.fromColor,
    required this.toColor,
    this.toNow = false,
  });

  final Duration gap;
  final double gapStrip;
  final int fromIndex;
  final int toIndex;
  final Color fromColor;
  final Color toColor;
  final bool toNow;

  @override
  Widget build(BuildContext context) {
    final fromOff = VineGeometry.offsetFor(fromIndex);
    final toOff = VineGeometry.offsetFor(toIndex);

    final stem = toNow
        ? _LiveGapStem(
            fromOffset: fromOff,
            toOffset: toOff,
            fromColor: fromColor,
            toColor: toColor,
          )
        : CustomPaint(
            painter: VineGapStemPainter(
              fromOffset: fromOff,
              toOffset: toOff,
              fromColor: fromColor,
              toColor: toColor,
            ),
          );

    // The elapsed figure belongs in the time gutter beside the clock times,
    // not punched through the stem: boxed on the vine it had to shrink to fit
    // the 72px band and came out an illegible smudge across a broken stem.
    //
    // Every interval on the vine is labelled, including the live one. Leaving
    // the last gap blank left a hole in the timeline's own grammar at exactly
    // the interval that matters most. It reads brighter and heavier than a
    // settled gap because it is the one number still moving; the status line
    // above keeps saying it too, so the figure survives being scrolled off on
    // a long day.
    return SizedBox(
      height: gapStrip,
      child: Row(
        children: [
          SizedBox(
            width: VineGeometry.timeGutter,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _gapLabel(gap),
                  style: TextStyle(
                    color: toNow
                        ? context.c.textSecondary
                        : context.c.textTertiary,
                    fontSize: 10.5,
                    fontWeight: toNow ? FontWeight.w600 : FontWeight.w500,
                    height: 1.1,
                    letterSpacing: 0.42, // ~0.04em at 10.5px
                    fontFeatures: _tabular,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: VineGeometry.vineBand,
            height: gapStrip,
            child: stem,
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  String _gapLabel(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return 'now';
  }
}

/// Animated dashed stem for the live gap (last dose → NOW). Isolated in its
/// own [RepaintBoundary] + ticker so the rest of the list never repaints.
class _LiveGapStem extends StatefulWidget {
  const _LiveGapStem({
    required this.fromOffset,
    required this.toOffset,
    required this.fromColor,
    required this.toColor,
  });

  final double fromOffset;
  final double toOffset;
  final Color fromColor;
  final Color toColor;

  @override
  State<_LiveGapStem> createState() => _LiveGapStemState();
}

class _LiveGapStemState extends State<_LiveGapStem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: VineGeometry.livePeriod,
    );
  }

  bool _shouldAnimate(BuildContext context) {
    if (!TickerMode.of(context)) return false;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return false;
    return !AppMotion.reduced(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start/stop outside build so reduced-motion and widget tests can settle.
    final animate = _shouldAnimate(context);
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveColor = context.c.accent;
    final animate = _shouldAnimate(context);

    Widget paint(double dashOffset) => CustomPaint(
      painter: VineGapStemPainter(
        fromOffset: widget.fromOffset,
        toOffset: widget.toOffset,
        fromColor: widget.fromColor,
        toColor: widget.toColor,
        live: true,
        dashOffset: dashOffset,
        liveColor: liveColor,
      ),
    );

    if (!animate) {
      return RepaintBoundary(child: paint(0));
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Travel −36 over one period so dashes flow toward NOW.
          final offset = -VineGeometry.liveDashTravel * _controller.value;
          return paint(offset);
        },
      ),
    );
  }
}

// ── NOW row ───────────────────────────────────────────────────────────────

class _NowRow extends StatelessWidget {
  const _NowRow({
    required this.nodeIndex,
    required this.nowPitch,
    required this.lastColor,
  });

  final int nodeIndex;
  final double nowPitch;
  final Color? lastColor;

  @override
  Widget build(BuildContext context) {
    final xOff = VineGeometry.offsetFor(nodeIndex);
    final tipColor = context.c.accent;
    final empty = lastColor == null;
    final fromColor = lastColor ?? tipColor;

    // On an empty today the row is handed the whole body height; the shoot
    // itself stays its designed length and sits centred in it.
    final band = math.min(nowPitch, VineRhythm.baseNow);

    return SizedBox(
      height: nowPitch,
      child: Center(
        child: SizedBox(
          height: band,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: VineGeometry.timeGutter,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    'now',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: context.c.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: VineGeometry.vineBand,
                height: band,
                // Final segment into NOW is always the live dashed tail today.
                child: _LiveNowStem(
                  xOffset: xOff,
                  fromColor: fromColor,
                  tipColor: tipColor,
                  hasPrior: !empty,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        empty ? 'NO DOSES YET' : 'NOW',
                        style: TextStyle(
                          color: context.c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      // Mirrors the dose row's sub-line, so the empty
                      // state sits on the same grid as a real one.
                      if (empty) ...[
                        const SizedBox(height: 5),
                        Text(
                          'tap + to log the first',
                          style: TextStyle(
                            color: context.c.textTertiary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated dashed young-shoot into the NOW disc on an empty today.
class _LiveNowStem extends StatefulWidget {
  const _LiveNowStem({
    required this.xOffset,
    required this.fromColor,
    required this.tipColor,
    required this.hasPrior,
  });

  final double xOffset;
  final Color fromColor;
  final Color tipColor;
  final bool hasPrior;

  @override
  State<_LiveNowStem> createState() => _LiveNowStemState();
}

class _LiveNowStemState extends State<_LiveNowStem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// With no dose yet the shoot has nothing to grow *from*, so instead of a
  /// static stub it sprouts on a loop — the empty day's only motion.
  bool get _sprouting => !widget.hasPrior;

  Duration get _period =>
      _sprouting ? VineGeometry.sproutPeriod : VineGeometry.livePeriod;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
  }

  bool _shouldAnimate(BuildContext context) {
    if (!TickerMode.of(context)) return false;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return false;
    return !AppMotion.reduced(context);
  }

  @override
  void didUpdateWidget(_LiveNowStem old) {
    super.didUpdateWidget(old);
    if (old.hasPrior == widget.hasPrior) return;
    _controller.duration = _period;
    if (_controller.isAnimating) _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = _shouldAnimate(context);
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveColor = context.c.accent;
    final animate = _shouldAnimate(context);

    Widget paint({double dashOffset = 0, double? sprout}) => CustomPaint(
      painter: VineNowStemPainter(
        xOffset: widget.xOffset,
        fromColor: widget.fromColor,
        tipColor: widget.tipColor,
        hasPrior: widget.hasPrior,
        live: true,
        dashOffset: dashOffset,
        liveColor: liveColor,
        sproutPhase: sprout,
      ),
    );

    // Reduced motion gets the shoot fully grown, not mid-sprout.
    if (!animate) {
      return RepaintBoundary(child: paint());
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return paint(
            dashOffset: -VineGeometry.liveDashTravel * t,
            sprout: _sprouting ? t : null,
          );
        },
      ),
    );
  }
}
