import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/geocoding_service.dart';
import '../utils/date_utils.dart' as du;
import '../theme/app_theme.dart';

class TripForm extends ConsumerStatefulWidget {
  final Trip? initialData;
  final void Function(Trip trip, bool saveAsCustomer) onSave;

  const TripForm({super.key, this.initialData, required this.onSave});

  @override
  ConsumerState<TripForm> createState() => _TripFormState();
}

class _TripFormState extends ConsumerState<TripForm> {
  final _formKey = GlobalKey<FormState>();
  late String _date;
  late String _startTime;
  late String _endTime;
  late String _destinationName;
  late String _destinationAddress;
  late double _distanceKm;
  late TripType _type;
  late TripStatus _status;
  late bool _isBilled;
  late bool _isLogged;
  late String _notes;
  late String? _vehicleId;
  bool _saveAsCustomer = false;
  bool _isGeocoding = false;
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _date = d?.date ?? du.todayIso();
    _startTime = d?.startTime ?? '';
    _endTime = d?.endTime ?? '';
    _destinationName = d?.destinationName ?? '';
    _destinationAddress = d?.destinationAddress ?? '';
    _distanceKm = d?.distanceKm ?? 0;
    _type = d?.type ?? TripType.business;
    _status = d?.status ?? TripStatus.completed;
    _isBilled = d?.isBilled ?? false;
    _isLogged = d?.isLogged ?? false;
    _notes = d?.notes ?? '';
    _vehicleId = d?.vehicleId;
    _addressController.text = _destinationAddress;
    if (_vehicleId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final vehicles = ref.read(vehiclesProvider);
        final def = vehicles.firstWhere((v) => v.isDefault, orElse: () => vehicles.isNotEmpty ? vehicles.first : const Vehicle(id: '', name: ''));
        if (def.id.isNotEmpty) setState(() => _vehicleId = def.id);
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (d != null) setState(() => _date = d.toIso8601String().substring(0, 10));
  }

  Future<void> _pickTime(bool isStart) async {
    final parts = (isStart ? _startTime : _endTime).split(':');
    final initial = parts.length == 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0)
        : TimeOfDay.now();
    final t = await showTimePicker(context: context, initialTime: initial);
    if (!mounted) return;
    if (t != null) {
      final s = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) { _startTime = s; } else { _endTime = s; }
      });
    }
  }

  Future<void> _geocodeCurrentLocation() async {
    if (_isGeocoding) return; // Prevent duplicate requests on rapid clicks
    setState(() => _isGeocoding = true);
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final address = await GeocodingService.instance.getAddress(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      if (address != null && address.isNotEmpty) {
        setState(() {
          _destinationAddress = address;
          _addressController.text = address;
        });
        // Try to match against customers
        final customers = ref.read(customersProvider);
        final match = GeocodingService.instance.matchCustomer(address, customers);
        if (match != null) {
          setState(() {
            _destinationName = match.name;
            _saveAsCustomer = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kunde erkannt: ${match.name}')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adresse konnte nicht ermittelt werden.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS-Zugriff fehlgeschlagen.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Validierung: endTime >= startTime (gleiche Minute ist erlaubt)
    if (_status == TripStatus.completed && _startTime.isNotEmpty && _endTime.isNotEmpty) {
      if (_endTime.compareTo(_startTime) < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Endzeit darf nicht vor der Startzeit liegen.')),
        );
        return;
      }
    }

    final trip = Trip(
      id: widget.initialData?.id ?? '',
      date: _date,
      startTime: _startTime,
      endTime: _status == TripStatus.planned ? '' : _endTime,
      destinationName: _destinationName,
      destinationAddress: _destinationAddress,
      distanceKm: _status == TripStatus.planned ? 0 : _distanceKm,
      type: _type,
      status: _status,
      isBilled: _isBilled,
      isLogged: _isLogged,
      notes: _notes,
      vehicleId: _vehicleId,
    );
    Navigator.pop(context);
    widget.onSave(trip, _saveAsCustomer);
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);
    final customers = ref.watch(customersProvider);
    final isPlanned = _status == TripStatus.planned;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.98,
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
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2))),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                child: Row(children: [
                  Text(widget.initialData != null ? 'Fahrt bearbeiten' : 'Neue Fahrt',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
              ),
              // Status toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<TripStatus>(
                  segments: const [
                    ButtonSegment(value: TripStatus.completed, label: Text('Abgeschlossen'), icon: Icon(Icons.check_circle_outline, size: 16)),
                    ButtonSegment(value: TripStatus.planned, label: Text('Geplant'), icon: Icon(Icons.calendar_today_outlined, size: 16)),
                  ],
                  selected: {_status},
                  onSelectionChanged: (v) => setState(() => _status = v.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppTheme.emerald,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    // Datum
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Datum', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(_date.isNotEmpty ? _date.split('-').reversed.join('.') : 'Datum wählen'),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: _pickDate,
                    ),
                    const Divider(),
                    // Zeiten
                    Row(children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Startzeit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text(_startTime.isEmpty ? 'Wählen' : _startTime),
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      if (!isPlanned)
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Endzeit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            subtitle: Text(_endTime.isEmpty ? 'Wählen' : _endTime),
                            onTap: () => _pickTime(false),
                          ),
                        ),
                    ]),
                    const Divider(),
                    // Ziel
                    const SizedBox(height: 8),
                    Autocomplete<Customer>(
                      initialValue: TextEditingValue(text: _destinationName),
                      optionsBuilder: (value) {
                        if (value.text.isEmpty) return const [];
                        return customers.where((c) => c.name.toLowerCase().contains(value.text.toLowerCase()));
                      },
                      displayStringForOption: (c) => c.name,
                      onSelected: (c) => setState(() {
                        _destinationName = c.name;
                        _destinationAddress = c.address;
                        _saveAsCustomer = false;
                      }),
                      fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                        controller.text = _destinationName;
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(labelText: 'Ziel (Name/Firma)'),
                          validator: (v) => v == null || v.isEmpty ? 'Pflichtfeld' : null,
                          onChanged: (v) => setState(() {
                            _destinationName = v;
                            final match = customers.firstWhere((c) => c.name.toLowerCase() == v.toLowerCase(), orElse: () => const Customer(id: '', name: '', address: ''));
                            if (match.id.isNotEmpty) {
                              _destinationAddress = match.address;
                              _saveAsCustomer = false;
                            }
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(labelText: 'Adresse (optional)'),
                            onChanged: (v) => _destinationAddress = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isGeocoding ? null : _geocodeCurrentLocation,
                          icon: _isGeocoding
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 20),
                          tooltip: 'Aktuelle Adresse ermitteln',
                          style: IconButton.styleFrom(
                            foregroundColor: AppTheme.emerald,
                          ),
                        ),
                      ],
                    ),
                    if (_destinationName.isNotEmpty && !customers.any((c) => c.name.toLowerCase() == _destinationName.toLowerCase()))
                      CheckboxListTile(
                        value: _saveAsCustomer,
                        onChanged: (v) => setState(() => _saveAsCustomer = v ?? false),
                        title: const Text('Als neues Ziel speichern', style: TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    const SizedBox(height: 12),
                    // Distanz (nur wenn abgeschlossen)
                    if (!isPlanned)
                      TextFormField(
                        initialValue: _distanceKm > 0 ? _distanceKm.toString() : '',
                        decoration: const InputDecoration(labelText: 'Distanz (km)', suffixText: 'km'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (isPlanned) return null;
                          final val = double.tryParse(v ?? '');
                          if (val == null || val < 0) return 'Gültige Zahl eingeben';
                          return null;
                        },
                        onChanged: (v) => _distanceKm = double.tryParse(v) ?? 0,
                      ),
                    const SizedBox(height: 12),
                    // Fahrttyp
                    const Text('Fahrttyp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    SegmentedButton<TripType>(
                      segments: const [
                        ButtonSegment(value: TripType.business, label: Text('Geschäftlich')),
                        ButtonSegment(value: TripType.private, label: Text('Privat')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (v) => setState(() => _type = v.first),
                    ),
                    const SizedBox(height: 12),
                    // Fahrzeug
                    if (vehicles.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _vehicleId,
                        decoration: const InputDecoration(labelText: 'Fahrzeug'),
                        items: vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text('${v.name}${v.licensePlate.isNotEmpty ? " (${v.licensePlate})" : ""}'))).toList(),
                        onChanged: (v) => setState(() => _vehicleId = v),
                      ),
                    const SizedBox(height: 12),
                    // Notizen
                    TextFormField(
                      initialValue: _notes,
                      decoration: const InputDecoration(labelText: 'Notizen (optional)'),
                      maxLines: 2,
                      onChanged: (v) => _notes = v,
                    ),
                    // Abgerechnet / Eingetragen (nur Geschäftlich + Abgeschlossen)
                    if (_type == TripType.business && !isPlanned) ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _isBilled,
                        onChanged: (v) => setState(() => _isBilled = v ?? false),
                        title: const Text('Zeit abgerechnet'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        value: _isLogged,
                        onChanged: (v) => setState(() => _isLogged = v ?? false),
                        title: const Text('Ins Fahrtenbuch eingetragen'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
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
