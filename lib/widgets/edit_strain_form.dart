import 'package:flutter/material.dart';

import '../models/strain.dart';
import 'strain_form_fields.dart';

class EditStrainForm extends StatelessWidget {
  const EditStrainForm({super.key, required this.strain});

  final Strain strain;

  @override
  Widget build(BuildContext context) => StrainFormFields(strain: strain);
}
