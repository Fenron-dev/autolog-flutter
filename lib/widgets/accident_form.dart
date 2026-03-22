import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/models.dart';
import '../utils/date_utils.dart' as du;

class AccidentForm extends StatefulWidget {
  final AccidentReport? initialData;
  final void Function(AccidentReport) onSave;

  const AccidentForm({super.key, this.initialData, required this.onSave});

  @override
  State<AccidentForm> createState() => _AccidentFormState();
}

class _AccidentFormState extends State<AccidentForm> {
  final _formKey = GlobalKey<FormState>();
  late String _date;
  late String _time;
  late String _location;
  late String _otherPartyName;
  late String _otherPartyAddress;
  late String _otherPartyPhone;
  late String _otherPartyInsurance;
  late String _remarks;
  late List<String> _photos;
  bool _loadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _date = d?.date ?? du.todayIso();
    _time = d?.time ?? du.nowTime();
    _location = d?.location ?? '';
    _otherPartyName = d?.otherPartyName ?? '';
    _otherPartyAddress = d?.otherPartyAddress ?? '';
    _otherPartyPhone = d?.otherPartyPhone ?? '';
    _otherPartyInsurance = d?.otherPartyInsurance ?? '';
    _remarks = d?.remarks ?? '';
    _photos = List.from(d?.photos ?? []);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d.toIso8601String().substring(0, 10));
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0)
        : TimeOfDay.now();
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null) {
      setState(() => _time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  static const _maxPhotos = 5;

  Future<void> _addPhoto() async {
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximal $_maxPhotos Fotos pro Unfallbericht.')),
      );
      return;
    }
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Kamera'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Galerie'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    setState(() => _loadingPhoto = true);
    try {
      final xFile = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 60);
      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        // Compress if needed
        final compressed = bytes.length > 200 * 1024
            ? await FlutterImageCompress.compressWithList(bytes, quality: 60, minWidth: 1024, minHeight: 1024)
            : bytes;
        final b64 = base64Encode(compressed);
        setState(() => _photos = [..._photos, 'data:image/jpeg;base64,$b64']);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto konnte nicht geladen werden: $e')));
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final report = AccidentReport(
      id: widget.initialData?.id ?? '',
      date: _date,
      time: _time,
      location: _location,
      otherPartyName: _otherPartyName,
      otherPartyAddress: _otherPartyAddress,
      otherPartyPhone: _otherPartyPhone,
      otherPartyInsurance: _otherPartyInsurance,
      remarks: _remarks,
      photos: _photos,
    );
    Navigator.pop(context);
    widget.onSave(report);
  }

  @override
  Widget build(BuildContext context) {
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                child: Row(children: [
                  const Icon(Icons.warning_amber_outlined, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(widget.initialData != null ? 'Unfallbericht bearbeiten' : 'Neuer Unfallbericht',
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
                    Text('Wann & Wo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Datum', style: TextStyle(fontSize: 12)),
                          subtitle: Text(_date.split('-').reversed.join('.')),
                          trailing: const Icon(Icons.calendar_today_outlined, size: 16),
                          onTap: _pickDate,
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Uhrzeit', style: TextStyle(fontSize: 12)),
                          subtitle: Text(_time),
                          trailing: const Icon(Icons.access_time_outlined, size: 16),
                          onTap: _pickTime,
                        ),
                      ),
                    ]),
                    TextFormField(
                      initialValue: _location,
                      decoration: const InputDecoration(labelText: 'Unfallort'),
                      validator: (v) => v == null || v.isEmpty ? 'Pflichtfeld' : null,
                      onChanged: (v) => _location = v,
                    ),
                    const Divider(height: 24),
                    Text('Unfallgegner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    TextFormField(initialValue: _otherPartyName, decoration: const InputDecoration(labelText: 'Name'), onChanged: (v) => _otherPartyName = v),
                    const SizedBox(height: 8),
                    TextFormField(initialValue: _otherPartyAddress, decoration: const InputDecoration(labelText: 'Adresse'), onChanged: (v) => _otherPartyAddress = v),
                    const SizedBox(height: 8),
                    TextFormField(initialValue: _otherPartyPhone, decoration: const InputDecoration(labelText: 'Telefon'), keyboardType: TextInputType.phone, onChanged: (v) => _otherPartyPhone = v),
                    const SizedBox(height: 8),
                    TextFormField(initialValue: _otherPartyInsurance, decoration: const InputDecoration(labelText: 'Versicherung & Kennzeichen'), onChanged: (v) => _otherPartyInsurance = v),
                    const Divider(height: 24),
                    Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    TextFormField(initialValue: _remarks, decoration: const InputDecoration(labelText: 'Hergang & Bemerkungen'), maxLines: 4, onChanged: (v) => _remarks = v),
                    const Divider(height: 24),
                    Row(children: [
                      Text('Fotos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1)),
                      const Spacer(),
                      if (_loadingPhoto)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      else if (_photos.length < _maxPhotos)
                        TextButton.icon(
                          onPressed: _addPhoto,
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: Text('Hinzufügen (${_photos.length}/$_maxPhotos)'),
                        )
                      else
                        Text('Max. $_maxPhotos Fotos', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                    if (_photos.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                        itemCount: _photos.length,
                        itemBuilder: (ctx, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(_photos[i].replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '')),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _photos = [..._photos]..removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                child: Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Speichern'),
                  )),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
