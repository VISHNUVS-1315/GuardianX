import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/medical_profile.dart';
import '../services/local_store.dart';

class MedicalIdScreen extends StatefulWidget {
  MedicalIdScreen({super.key});

  @override
  State<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends State<MedicalIdScreen>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _blood = TextEditingController();
  final _allergies = TextEditingController();
  final _medications = TextEditingController();
  final _conditions = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await LocalStore.loadMedicalProfile();
    _name.text = profile.fullName;
    _blood.text = profile.bloodGroup;
    _allergies.text = profile.allergies;
    _medications.text = profile.medications;
    _conditions.text = profile.conditions;
    _note.text = profile.emergencyNote;
    if (mounted) setState(() {});
  }

  MedicalProfile _profile() => MedicalProfile(
        fullName: _name.text.trim(),
        bloodGroup: _blood.text.trim(),
        allergies: _allergies.text.trim(),
        medications: _medications.text.trim(),
        conditions: _conditions.text.trim(),
        emergencyNote: _note.text.trim(),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await LocalStore.saveMedicalProfile(_profile());
      _snack('Medical ID saved in encrypted device storage.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _profile().toEmergencyText()));
    _snack('Medical ID copied.');
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _blood,
      _allergies,
      _medications,
      _conditions,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 110),
          children: [
            Text(
              'Medical ID',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              'Emergency health details are encrypted on this device.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: 20),
            _field(_name, 'Full name', Icons.person_outline),
            _field(
              _blood,
              'Blood group',
              Icons.bloodtype_outlined,
              required: true,
            ),
            _field(_allergies, 'Allergies', Icons.warning_amber_outlined),
            _field(_medications, 'Current medications', Icons.medication),
            _field(_conditions, 'Medical conditions', Icons.monitor_heart),
            _field(
              _note,
              'Emergency note',
              Icons.note_alt_outlined,
              lines: 3,
            ),
            SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Icon(Icons.lock_outline),
              label: Text('Save Medical ID'),
            ),
            SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: Icon(Icons.copy),
              label: Text('Copy emergency summary'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    int lines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: required
            ? (value) => (value == null || value.trim().isEmpty)
                ? '$label is required'
                : null
            : null,
      ),
    );
  }
}
