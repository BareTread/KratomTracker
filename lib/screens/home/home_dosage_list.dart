import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

/// Sans amount. Digits keep [style]; the unit letter drops to 85%.
/// No characters are inserted, so plain text is unchanged.
Text _amountText(String text, TextStyle style) {
  final unit = style.copyWith(fontSize: (style.fontSize ?? 13) * 0.85);
  return Text.rich(
    TextSpan(
      style: style,
      children: [
        for (final match in RegExp(r'[ghmd]|[^ghmd]+').allMatches(text))
          TextSpan(
            text: match[0],
            style: _isUnitLetter(match[0]!) ? unit : null,
          ),
      ],
    ),
  );
}

bool _isUnitLetter(String part) => part.length == 1 && 'ghmd'.contains(part);

/// Dose ids the ledger has already shown, keyed by day. A row whose id first
/// appears on a later build — one just logged — is the only row whose mark
/// settles in; a day's first build records its ids without animating.
final Map<DateTime, Set<String>> _seenDoseIdsByDay = {};

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
    this.now,
    this.reveal,
    this.header = const SizedBox.shrink(),
  });

  final List<Dosage> dosages;
  final Map<String, Strain> strainsById;

  /// When true, the vine continues past the last dose to a terminal NOW node.
  final bool isToday;

  /// Ticking clock the live gap label listens to. Null (tests, static
  /// embeds) keeps the label computed once at build, as before.
  final ValueListenable<DateTime>? now;

  /// 0→1 entrance clock for the day. Rows rise in on it one beat apart; null
  /// (tests, static embeds) shows everything at rest.
  final Animation<double>? reveal;

  /// Optional widget rendered above the vine (kept for call-site compatibility).
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final sorted = [...dosages]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Ids already shown for this day: on the day's first build everything is
    // recorded quietly; on later builds an unseen id is a just-logged dose
    // whose mark settles in once (see [_MarkSettle]).
    final dayKey = DateUtils.dateOnly(
      sorted.isEmpty ? DateTime.now() : sorted.first.timestamp.toLocal(),
    );
    final daySeen = _seenDoseIdsByDay.containsKey(dayKey);
    final seen = _seenDoseIdsByDay.putIfAbsent(dayKey, () => <String>{});
    final justLogged = <String>{};
    for (final dose in sorted) {
      if (seen.add(dose.id) && daySeen) justLogged.add(dose.id);
    }

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
            liveFrom: last!.timestamp,
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
                  reveal: reveal,
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
                  settles: justLogged.contains(item.dosage!.id),
                ),
              _Kind.gap => _GapRow(
                  gap: item.gap!,
                  gapStrip: rhythm.gapStrip,
                  reveal: reveal,
                  fromIndex: item.fromIndex,
                  toIndex: item.toIndex,
                  liveFrom: item.liveFrom,
                  now: now,
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
                  reveal: reveal,
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
    this.liveFrom,
    this.lastColor,
  });

  factory _VineItem.dose(Dosage d, {required int nodeIndex}) =>
      _VineItem._(kind: _Kind.dose, dosage: d, nodeIndex: nodeIndex);

  factory _VineItem.gap(
    Duration gap, {
    required int fromIndex,
    required int toIndex,
    bool toNow = false,
    DateTime? liveFrom,
  }) =>
      _VineItem._(
        kind: _Kind.gap,
        gap: gap,
        fromIndex: fromIndex,
        toIndex: toIndex,
        toNow: toNow,
        liveFrom: liveFrom,
      );

  factory _VineItem.now({required int nodeIndex, Color? lastColor}) =>
      _VineItem._(kind: _Kind.now, nodeIndex: nodeIndex, lastColor: lastColor);

  final _Kind kind;
  final Dosage? dosage;
  final Duration? gap;

  /// Anchor for the live (to NOW) gap label: recompute, don't freeze.
  final DateTime? liveFrom;
  final int nodeIndex;
  final int fromIndex;
  final int toIndex;
  final bool toNow;
  final Color? lastColor;
}

// ── Entrance ──────────────────────────────────────────────────────────────

/// One beat of the day's entrance. Each step starts a little after the one
/// above it and eases out, so the ledger settles top to bottom instead of
/// appearing as a single block. Rows built later by scrolling see the clock
/// already finished and show at rest.
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.reveal,
    required this.step,
    required this.child,
    this.delay = 0,
    this.rise = 12,
    this.scaleFrom,
    this.curve = AppMotion.spring,
  });

  final Animation<double>? reveal;
  final int step;
  final Widget child;

  /// Extra start offset, in fractions of the whole entrance.
  final double delay;

  /// Pixels the content travels up while it fades in.
  final double rise;
  final double? scaleFrom;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final clock = reveal;
    if (clock == null || clock.isCompleted) return child;
    final start = math.min(step, 7) * 0.075 + delay;
    final t = clock.drive(
      CurveTween(curve: Interval(start, math.min(1, start + 0.45))),
    );
    return AnimatedBuilder(
      animation: t,
      child: child,
      builder: (context, child) {
        final v = curve.transform(t.value);
        Widget out = child!;
        if (scaleFrom != null) {
          out = Transform.scale(
            scale: scaleFrom! + (1 - scaleFrom!) * v,
            child: out,
          );
        }
        if (rise != 0) {
          out = Transform.translate(
            offset: Offset(0, rise * (1 - v)),
            child: out,
          );
        }
        return Opacity(opacity: t.value.clamp(0.0, 1.0), child: out);
      },
    );
  }
}

// ── Dose row ──────────────────────────────────────────────────────────────

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.dosage,
    required this.strain,
    required this.nodeIndex,
    required this.rowPitch,
    required this.reveal,
    required this.prevColor,
    required this.nextColor,
    required this.isFirst,
    required this.isLast,
    required this.settles,
  });

  final Dosage dosage;
  final Strain? strain;
  final int nodeIndex;
  final double rowPitch;
  final Animation<double>? reveal;
  final Color? prevColor;
  final Color? nextColor;
  final bool isFirst;
  final bool isLast;

  /// Fixed gram scale (max single dose across days) the gram-leaf maps onto.
  /// True only for a dose that just appeared (logged while Home was
  /// showing its day): its mark settles in once.
  final bool settles;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final rawColor =
        strain == null ? context.c.textTertiary : Color(strain!.color);
    final leafColor = legibleStrainColor(rawColor, brightness);
    final code = strain?.code ?? '???';
    // Small text needs more than the leaf's own legibility band: pale hues
    // (yellow, white) sit near 2:1 on cream at 13px, so on light the label
    // is pulled darker while the leaf keeps the strain's true colour.
    final leafHsl = HSLColor.fromColor(leafColor);
    final codeColor = brightness == Brightness.light
        ? leafHsl.withLightness(math.min(leafHsl.lightness, 0.33)).toColor()
        : leafColor;
    // The code is the identity; the full name only earns a line when it says
    // something the code doesn't.
    final fullName = strain?.name.trim() ?? '';
    final showName =
        fullName.isNotEmpty && fullName.toLowerCase() != code.toLowerCase();
    final shape = resolveLeafShape(strain?.icon ?? '', strain?.code ?? '');
    final xOff = VineGeometry.offsetFor(nodeIndex);

    final localTimestamp = dosage.timestamp.toLocal();
    final hour = DateFormat('h:mm').format(localTimestamp);
    final ampm = DateFormat('a').format(localTimestamp).toUpperCase();

    final semantics =
        '$hour $ampm, $code${showName ? ' ($fullName)' : ''}, ${dosage.amount} grams';

    // Stem colour above/below the leaf so segments join with neighbours.
    final above = prevColor ?? leafColor;
    final below = nextColor ?? leafColor;

    return Semantics(
      button: true,
      label: semantics,
      child: _Entrance(
        reveal: reveal,
        step: nodeIndex,
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
                    // scaleDown keeps "12:00" inside the fixed gutter when the
                    // system font scale is large, instead of overflowing.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
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
                        child: _Entrance(
                          reveal: reveal,
                          step: nodeIndex,
                          delay: 0.04,
                          rise: 0,
                          scaleFrom: 0.55,
                          curve: Curves.easeOutBack,
                          child: _MarkSettle(
                            animate: settles,
                            child: StrainMark(
                              shape: shape,
                              color: leafColor,
                              size: VineGeometry.leafSize,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content — the strain CODE leads: it is the identity people
                // read the day by, and it changes from dose to dose while the
                // amount barely does. It carries the strain's colour. Under it,
                // quiet supporting text: the amount, then the full name.
                // Nothing is pinned to the right margin, so the last row of a
                // full day can't end up under the add button.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: codeColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _amountText(
                              _formatAmount(dosage.amount),
                              TextStyle(
                                fontFamily: AppType.sans,
                                color: context.c.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                                fontFeatures: _tabular,
                              ),
                            ),
                            if (showName) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.c.textTertiary
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.c.textTertiary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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

/// A just-logged dose's mark settles in once: scale 0.6→1 with a fade,
/// 200 ms easeOutCubic, no bounce. [animate] false (or OS animations off)
/// shows it at rest. The controller only ever forwards once, so rebuilds
/// can't restart it.
class _MarkSettle extends StatefulWidget {
  const _MarkSettle({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_MarkSettle> createState() => _MarkSettleState();
}

class _MarkSettleState extends State<_MarkSettle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _settle = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _played = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_played) return;
    _played = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _settle,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(_settle),
        child: widget.child,
      ),
    );
  }
}

// ── Gap strip ─────────────────────────────────────────────────────────────

class _GapRow extends StatelessWidget {
  const _GapRow({
    required this.gap,
    required this.gapStrip,
    required this.reveal,
    required this.fromIndex,
    required this.toIndex,
    required this.fromColor,
    required this.toColor,
    this.toNow = false,
    this.liveFrom,
    this.now,
  });

  final Duration gap;
  final double gapStrip;
  final Animation<double>? reveal;
  final int fromIndex;
  final int toIndex;
  final Color fromColor;
  final Color toColor;
  final bool toNow;

  /// When [toNow], the gap is live: the label recomputes from this dose's
  /// timestamp against the ticking [now] instead of freezing at build time.
  final DateTime? liveFrom;
  final ValueListenable<DateTime>? now;

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

    // Gap labels only exist from one minute up; under a minute the strip
    // stays blank — the NOW row already says it, and a settled gap of 0m is
    // not "now". The live label keeps ticking so it appears once a minute passes.
    final liveAnchor = liveFrom;
    Widget gutterLabel(Duration d) {
      final text = _gapLabel(d);
      if (text.isEmpty) return const SizedBox.shrink();
      return Text(
        text,
        style: TextStyle(
          color: toNow ? context.c.textSecondary : context.c.textTertiary,
          fontSize: 11,
          fontWeight: toNow ? FontWeight.w600 : FontWeight.w500,
          height: 1.1,
          letterSpacing: 0.42, // ~0.04em at 11px
          fontFeatures: _tabular,
        ),
      );
    }

    final label = (toNow && liveAnchor != null && now != null)
        ? ValueListenableBuilder<DateTime>(
            valueListenable: now!,
            builder: (context, tick, _) =>
                gutterLabel(tick.difference(liveAnchor)),
          )
        : gutterLabel(gap);

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
                child: _Entrance(
                  reveal: reveal,
                  step: toIndex,
                  rise: 4,
                  child: label,
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
    return '';
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
    if (!TickerMode.valuesOf(context).enabled) return false;
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
          // Travel −36 over one period so dashes flow toward NOW, quantized
          // to whole-pixel phases: sub-pixel steps are invisible at this
          // drift rate, and equal consecutive offsets make shouldRepaint
          // false so the raster is skipped between steps.
          final offset = quantizeLiveDashOffset(
            -VineGeometry.liveDashTravel * _controller.value,
          );
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
    required this.reveal,
    required this.lastColor,
  });

  final int nodeIndex;
  final double nowPitch;
  final Animation<double>? reveal;
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
              const SizedBox(width: VineGeometry.timeGutter),
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
                  child: _Entrance(
                    reveal: reveal,
                    step: nodeIndex,
                    // The band is a fixed height; at a very large system font
                    // the two lines shrink to fit rather than clip.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
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
    if (!TickerMode.valuesOf(context).enabled) return false;
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
            // Quantized so the steady tail (dashes only) skips repaints
            // between phase steps; the sprout keeps its full phase
            // resolution for smooth growth.
            dashOffset: quantizeLiveDashOffset(
              -VineGeometry.liveDashTravel * t,
            ),
            sprout: _sprouting ? t : null,
          );
        },
      ),
    );
  }
}
