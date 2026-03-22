import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/date_utils.dart' as du;

class VehicleForm extends StatefulWidget {
  final Vehicle? initialData;
  final void Function(Vehicle) onSave;

  const VehicleForm({super.key, this.initialData, required this.onSave});

  @override
  State<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<VehicleForm> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _manufacturer;
  late String _licensePlate;
  late String _initialMileage;
  late String _initialMileageDate;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _name = d?.name ?? '';
    _manufacturer = d?.manufacturer ?? '';
    _licensePlate = d?.licensePlate ?? '';
    _initialMileage = d?.initialMileage.toStringAsFixed(0) ?? '0';
    _initialMileageDate = d?.initialMileageDate ?? du.todayIso();
    _isDefault = d?.isDefault ?? false;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_initialMileageDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _initialMileageDate = d.toIso8601String().substring(0, 10));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final vehicle = Vehicle(
      id: widget.initialData?.id ?? '',
      name: _name,
      manufacturer: _manufacturer,
      licensePlate: _licensePlate,
      initialMileage: double.tryParse(_initialMileage) ?? 0,
      initialMileageDate: _initialMileageDate,
      isDefault: _isDefault,
    );
    Navigator.pop(context);
    widget.onSave(vehicle);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                child: Row(children: [
                  const Icon(Icons.directions_car_outlined, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Text(widget.initialData != null ? 'Fahrzeug bearbeiten' : 'Neues Fahrzeug',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    TextFormField(
                      initialValue: _name,
                      decoration: const InputDecoration(labelText: 'Name (z.B. Mein Audi)'),
                      validator: (v) => v == null || v.isEmpty ? 'Pflichtfeld' : null,
                      onChanged: (v) => _name = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _manufacturer,
                      decoration: const InputDecoration(labelText: 'Hersteller (optional)'),
                      onChanged: (v) => _manufacturer = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _licensePlate,
                      decoration: const InputDecoration(labelText: 'Kennzeichen (optional)'),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (v) => _licensePlate = v,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _initialMileage,
                          decoration: const InputDecoration(labelText: 'Anfänglicher Zählerstand (km)'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n < 0) return 'Gültige Zahl';
                            return null;
                          },
                          onChanged: (v) => _initialMileage = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ablesedatum', style: TextStyle(fontSize: 12)),
                          subtitle: Text(_initialMileageDate.split('-').reversed.join('.')),
                          trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                          onTap: _pickDate,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v ?? false),
                      title: const Text('Als Standardfahrzeug'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                child: Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: _submit, child: const Text('Speichern'))),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
