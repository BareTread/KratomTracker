import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import '../widgets/add_strain_form.dart';
import '../domain/strain_usage.dart';
import '../models/strain.dart';
import '../widgets/sheet_header.dart';
import '../widgets/strain_details_view.dart';
import '../widgets/strain_mark.dart';
import '../widgets/strain_usage_tile.dart';
import '../theme/app_theme.dart';

/// The strains index: rows sit directly on the screen background behind
/// hairline dividers, stock is stated only when it is the exception, and the
/// single action lives in the header. Edit/delete/stock toggling moved into
/// the details sheet each row opens.
class StrainsScreen extends StatelessWidget {
  const StrainsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        // Same order as the dose sheet: next-up suggestion first, out of
        // stock last. Strains the usage list does not know keep list order.
        final usage = provider.strainUsage;
        final usageByStrain = <String, StrainUsage>{
          for (final u in usage) u.strain.id: u,
        };
        final all = provider.strains;
        final rank = <String, int>{
          for (var i = 0; i < all.length; i++) all[i].id: usage.length + i,
          for (var i = 0; i < usage.length; i++) usage[i].strain.id: i,
        };
        final strains = [...all]..sort((a, b) {
            if (a.inStock != b.inStock) return a.inStock ? -1 : 1;
            return rank[a.id]!.compareTo(rank[b.id]!);
          });

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 8),
              _Head(
                strains: strains,
                onAdd: () => _showAddStrainForm(context),
              ),
              Expanded(
                child: strains.isEmpty
                    ? _EmptyState(onAdd: () => _showAddStrainForm(context))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        itemCount: strains.length,
                        separatorBuilder: (context, index) => Padding(
                          // Indented to the text column so the hairline
                          // starts beside the mark, not under it.
                          padding: const EdgeInsets.only(left: 66, right: 16),
                          child: Container(height: 1, color: context.c.hairline),
                        ),
                        itemBuilder: (context, index) {
                          final strain = strains[index];
                          return _StrainRow(
                            strain: strain,
                            usage: usageByStrain[strain.id],
                            onTap: () => _showStrainDetails(context, strain),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStrainDetails(BuildContext context, Strain strain) {
    showAppSheet(context, builder: (context) => StrainDetailsView(strain: strain));
  }

  void _showAddStrainForm(BuildContext context) {
    showAppSheet(context, builder: (context) => const AddStrainForm());
  }
}

/// Title row plus the quiet count line. The add action sits on the title row
/// and is hidden when there is nothing to index — the empty state carries
/// the only action instead.
class _Head extends StatelessWidget {
  final List<Strain> strains;
  final VoidCallback onAdd;

  const _Head({required this.strains, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final outOfStock = strains.where((s) => !s.inStock).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Strains',
                  style: AppType.display(size: 36, color: c.textPrimary),
                ),
              ),
              if (strains.isNotEmpty)
                _AddStrainAction(label: 'Add strain', onTap: onAdd),
            ],
          ),
          if (outOfStock > 0)
            Text(
              '$outOfStock out of stock',
              style: TextStyle(
                fontFamily: AppType.sans,
                color: c.textTertiary,
                fontSize: 14,
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}

/// One index row: mark, code + name, the dose sheet's recency line, and a
/// stock word only when the strain is out. No card, no menu, no chip.
class _StrainRow extends StatelessWidget {
  final Strain strain;
  final StrainUsage? usage;
  final VoidCallback onTap;

  const _StrainRow({
    required this.strain,
    required this.usage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final brightness = Theme.of(context).brightness;
    final strainColor = Color(strain.color);
    final inStock = strain.inStock;

    final showName = strain.name.trim().isNotEmpty &&
        strain.name.trim().toLowerCase() != strain.code.trim().toLowerCase();

    final secondLine = usage == null || usage!.lastUsed == null
        ? 'Not used yet'
        : strainRecencyLine(usage!);

    final semantics = StringBuffer(strain.code)
      ..write(showName ? ', ${strain.name}' : '')
      ..write(', $secondLine')
      ..write(inStock ? ', in stock' : ', out of stock');

    return Semantics(
      button: true,
      label: semantics.toString(),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                StrainMark(
                  shape: resolveLeafShape(strain.icon, strain.code),
                  color: strainColor,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: inStock ? 1.0 : 0.55,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                strain.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppType.sans,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: legibleStrainColor(
                                    strainColor,
                                    brightness,
                                  ),
                                ),
                              ),
                            ),
                            if (showName) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 2,
                                child: Text(
                                  strain.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppType.sans,
                                    fontSize: 15,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          secondLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppType.sans,
                            fontSize: 13,
                            height: 1.25,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!inStock) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Out of stock',
                    style: TextStyle(
                      fontFamily: AppType.sans,
                      fontSize: 12,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First run: two calm lines of orientation and the one accent action the
/// head row hides when the index is empty.
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No strains yet',
            style: TextStyle(
              fontFamily: AppType.sans,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add the strains you keep on hand. Each gets a code and a colour '
            'that marks its doses everywhere in the app.',
            style: TextStyle(
              fontFamily: AppType.sans,
              fontSize: 14,
              height: 1.4,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _AddStrainAction(label: 'Add a strain', onTap: onAdd),
        ],
      ),
    );
  }
}

/// The restrained accent text action used by the head row and the empty
/// state: a plus glyph and a label inside a 48dp tap target.
class _AddStrainAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddStrainAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: const Key('strains-add'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: c.textPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
