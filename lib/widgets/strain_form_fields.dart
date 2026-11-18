import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/strain.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import 'sheet_header.dart';
import 'strain_mark.dart';

class _Shade {
  const _Shade(this.name, this.intensity, this.color);
  final String name;
  final String intensity;
  final Color color;
}

// These are strain identity colours, including the original add-form palette.
const _palettes = <String, List<_Shade>>{
  'Green': [_Shade('Forest', 'Mild', Color(0xFF2E7D32)), _Shade('Jade', 'Medium', Color(0xFF4CAF50)), _Shade('Mint', 'Strong', Color(0xFF81C784))],
  'Red': [_Shade('Ruby', 'Mild', Color(0xFFB71C1C)), _Shade('Crimson', 'Medium', Color(0xFFE53935)), _Shade('Garnet', 'Strong', Color(0xFFEF5350))],
  'White': [_Shade('Pearl', 'Mild', Color(0xFFE3F2FD)), _Shade('Silver', 'Medium', Color(0xFFBBDEFB)), _Shade('Platinum', 'Strong', Color(0xFF90CAF9))],
  'Yellow': [_Shade('Sunrise', 'Mild', Color(0xFFF9A825)), _Shade('Gold', 'Medium', Color(0xFFFDD835)), _Shade('Amber', 'Strong', Color(0xFFFFEE58))],
};

double _distance(Color a, Color b) {
  final dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b;
  return dr * dr + dg * dg + db * db;
}

class StrainFormFields extends StatefulWidget {
  const StrainFormFields({super.key, this.strain});
  final Strain? strain;

  @override
  State<StrainFormFields> createState() => _StrainFormFieldsState();
}

class _StrainFormFieldsState extends State<StrainFormFields> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  String _type = 'Green';
  late Color _color;
  late LeafShape _shape;
  late bool _inStock;
  bool _stockEdited = false;

  @override
  void initState() {
    super.initState();
    final strain = widget.strain;
    _name = TextEditingController(text: strain?.name);
    _code = TextEditingController(text: strain?.code);
    _color = strain == null ? _palettes['Green']!.first.color : Color(strain.color);
    // A colour from outside today's palettes (older versions, imports) still
    // opens under the nearest family, so a red strain never reads as Green.
    var best = double.infinity;
    for (final entry in _palettes.entries) {
      for (final shade in entry.value) {
        final d = _distance(shade.color, _color);
        if (d < best) {
          best = d;
          _type = entry.key;
        }
      }
    }
    // Earlier edit forms offered a different set of white shades.
    if (const [0xFFCFD8DC, 0xFFB0BEC5, 0xFF90A4AE].contains(_color.toARGB32())) {
      _type = 'White';
    }
    _shape = strain == null ? LeafShape.lance : resolveLeafShape(strain.icon, strain.code);
    _inStock = strain?.inStock ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<KratomProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final strain = widget.strain;
      if (strain == null) {
        await provider.addStrain(_name.text.trim(), _code.text.trim(), _color.toARGB32(), _shape.name, inStock: _inStock);
      } else {
        await provider.updateStrain(strain.id, name: _name.text.trim(), code: _code.text.trim(), color: _color.toARGB32(), icon: _shape.name, inStock: _stockEdited ? _inStock : provider.getStrain(strain.id)?.inStock);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save strain: $e'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final collision = markCollision(
      context.read<KratomProvider>().strains.map((s) => (id: s.id, name: s.name, color: s.color, icon: s.icon, code: s.code)).toList(growable: false),
      _color.toARGB32(), _shape, excludeId: widget.strain?.id,
    );
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Material(
        color: c.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, constraints) {
          final maxHeight = constraints.hasBoundedHeight ? constraints.maxHeight : MediaQuery.sizeOf(context).height - keyboard;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SheetHeader(title: widget.strain == null ? 'Add strain' : 'Edit strain', trailing: IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))),
                Flexible(child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: SheetHeader.inset),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a name' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Code', hintText: '2–4 letters, shown on every dose'), validator: (value) {
                      final code = value?.trim() ?? '';
                      if (code.isEmpty) return 'Please enter a code';
                      if (widget.strain == null && (code.length < 2 || code.length > 4)) return 'Code must be 2-4 letters';
                      return null;
                    },),
                    const SizedBox(height: 24),
                    Text('Colour', style: sectionLabelStyle(context)),
                    const SizedBox(height: 8),
                    Row(children: [for (final type in _palettes.keys) Expanded(child: Padding(
                      padding: EdgeInsets.only(right: type == 'Yellow' ? 0 : 6),
                      child: OutlinedButton(
                        onPressed: () => setState(() { _type = type; _color = _palettes[type]!.first.color; }),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: EdgeInsets.zero, foregroundColor: _type == type ? c.textPrimary : c.textSecondary, side: BorderSide(color: _type == type ? c.textPrimary : c.hairline), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(type)),
                      ),
                    ),),],),
                    const SizedBox(height: 12),
                    Row(children: [for (final shade in _palettes[_type]!) Expanded(child: Padding(
                      padding: EdgeInsets.only(right: identical(shade, _palettes[_type]!.last) ? 0 : 8),
                      child: Semantics(button: true, selected: _color == shade.color, label: '${shade.name}, ${shade.intensity}', child: InkWell(
                        onTap: () => setState(() => _color = shade.color),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(height: 64, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(12), border: Border.all(color: _color == shade.color ? c.textPrimary : c.hairline, width: _color == shade.color ? 2 : 1)), child: Row(children: [
                          Container(width: 20, height: 20, decoration: BoxDecoration(color: shade.color, shape: BoxShape.circle, border: Border.all(color: c.hairline))),
                          const SizedBox(width: 6),
                          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(shade.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AppType.sans, color: c.textPrimary, fontSize: 13)), Text(shade.intensity, style: TextStyle(fontFamily: AppType.sans, color: c.textSecondary, fontSize: 11))])),
                        ],),),
                      ),),
                    ),),],),
                    const SizedBox(height: 24),
                    Text('Mark', style: sectionLabelStyle(context)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [for (final shape in LeafShape.values) Semantics(
                      button: true, selected: _shape == shape, label: '${shape.label}${collision.takenForColor.contains(shape) ? ', already in use' : ''}',
                      child: InkWell(onTap: () => setState(() => _shape = shape), borderRadius: BorderRadius.circular(12), child: Container(
                        width: 48, height: 48, decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(12), border: Border.all(color: _shape == shape ? c.textPrimary : c.hairline, width: _shape == shape ? 2 : 1)),
                        child: Stack(children: [Center(child: StrainMark(shape: shape, color: _shape == shape ? legibleStrainColor(_color, Theme.of(context).brightness) : c.textTertiary, size: 26)), if (collision.takenForColor.contains(shape)) Positioned(right: 4, top: 4, child: Container(width: 6, height: 6, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)))]),
                      ),),
                    ),],),
                    if (collision.ownerName != null) ...[const SizedBox(height: 10), Text('This colour and mark are already used by ${collision.ownerName}. Pick a free mark, or keep it if you mean to share them.', style: TextStyle(fontFamily: AppType.sans, fontSize: 13, color: c.caution))],
                    const SizedBox(height: 24),
                    Text('Stock', style: sectionLabelStyle(context)),
                    SwitchListTile(value: _inStock, onChanged: (value) => setState(() { _inStock = value; _stockEdited = true; }), title: const Text('In stock'), subtitle: const Text("Turn off when you don't have it on hand. Keeps the history; drops it below the picker line."), contentPadding: EdgeInsets.zero),
                  ],),
                ),),
                Padding(padding: EdgeInsets.fromLTRB(SheetHeader.inset, 12, SheetHeader.inset, 12 + MediaQuery.paddingOf(context).bottom), child: Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, style: FilledButton.styleFrom(minimumSize: const Size(0, 48), backgroundColor: c.accent, foregroundColor: Theme.of(context).brightness == Brightness.dark ? c.surfaceSunken : c.textPrimary), child: Text(widget.strain == null ? 'Add strain' : 'Save')))),
              ],),
            ),
          );
        },),
      ),
    );
  }
}
