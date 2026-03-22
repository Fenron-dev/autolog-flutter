import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/export_utils.dart';
import '../widgets/vehicle_form.dart';
import 'archive_screen.dart';
import 'accidents_screen.dart';
import 'import_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final trips = ref.watch(tripsProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final allTrips = [...trips.activeTrips, ...trips.archivedTrips];
    final completed = allTrips.where((t) => t.status == TripStatus.completed).toList();
    final totalKm = completed.fold(0.0, (s, t) => s + t.distanceKm);
    final businessKm = completed.where((t) => t.type == TripType.business).fold(0.0, (s, t) => s + t.distanceKm);
    final privateKm = completed.where((t) => t.type == TripType.private).fold(0.0, (s, t) => s + t.distanceKm);
    final days = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen', style: TextStyle(fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Statistik
          _SectionCard(
            title: 'Statistik',
            child: Row(children: [
              Expanded(child: _StatItem(icon: Icons.directions_car_outlined, label: 'Gesamt', value: '${totalKm.toStringAsFixed(1)} km', color: Colors.grey.shade600)),
              Expanded(child: _StatItem(icon: Icons.business_center_outlined, label: 'Geschäftlich', value: '${businessKm.toStringAsFixed(1)} km', color: Colors.green.shade600)),
              Expanded(child: _StatItem(icon: Icons.coffee_outlined, label: 'Privat', value: '${privateKm.toStringAsFixed(1)} km', color: Colors.amber.shade700)),
            ]),
          ),
          const SizedBox(height: 12),

          // Fahrzeuge
          _SectionCard(
            title: 'Fahrzeuge',
            trailing: IconButton(
              onPressed: () => _showVehicleForm(context, ref, null),
              icon: const Icon(Icons.add, color: AppTheme.emerald),
            ),
            child: Column(
              children: vehicles.map((v) {
                final vTrips = completed.where((t) => t.vehicleId == v.id && (v.initialMileageDate == null || t.date.compareTo(v.initialMileageDate!) >= 0));
                final vKm = vTrips.fold(0.0, (s, t) => s + t.distanceKm);
                final current = v.initialMileage + vKm;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(children: [
                    Text(v.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (v.isDefault) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)), child: Text('Standard', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)))],
                  ]),
                  subtitle: Text('${v.manufacturer}${v.licensePlate.isNotEmpty ? " • ${v.licensePlate}" : ""}\nZähler: ${current.toStringAsFixed(1)} km'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'edit': _showVehicleForm(context, ref, v);
                        case 'default': ref.read(vehiclesProvider.notifier).setDefault(v.id);
                        case 'history': Navigator.push(context, MaterialPageRoute(builder: (_) => ArchiveScreen(title: 'Fahrzeughistorie', trips: allTrips.where((t) => t.vehicleId == v.id).toList(), vehicles: vehicles)));
                        case 'delete': _confirmDeleteVehicle(context, ref, v);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                      if (!v.isDefault) const PopupMenuItem(value: 'default', child: Text('Als Standard')),
                      const PopupMenuItem(value: 'history', child: Text('Historie')),
                      const PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Archive & Accidents
          _SectionCard(
            title: 'Verwaltung',
            child: Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline),
                title: const Text('Papierkorb'),
                subtitle: Text('${trips.deletedTrips.length} gelöschte Fahrten'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArchiveScreen(title: 'Papierkorb', trips: trips.deletedTrips, vehicles: vehicles, isTrash: true))),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archiv'),
                subtitle: Text('${trips.archivedTrips.length} archivierte Fahrten (>1 Jahr)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArchiveScreen(title: 'Archiv', trips: trips.archivedTrips, vehicles: vehicles))),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_outlined, color: Colors.red),
                title: const Text('Unfallberichte'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccidentsScreen())),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Theme
          _SectionCard(
            title: 'Erscheinungsbild',
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'light', label: Text('Hell'), icon: Icon(Icons.light_mode_outlined, size: 16)),
                ButtonSegment(value: 'system', label: Text('System'), icon: Icon(Icons.brightness_auto_outlined, size: 16)),
                ButtonSegment(value: 'dark', label: Text('Dunkel'), icon: Icon(Icons.dark_mode_outlined, size: 16)),
              ],
              selected: {settings.theme},
              onSelectionChanged: (v) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(theme: v.first)),
            ),
          ),
          const SizedBox(height: 12),

          // Erinnerungen
          _SectionCard(
            title: 'Erinnerungen',
            trailing: Switch(
              value: settings.reminderEnabled,
              onChanged: (v) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(reminderEnabled: v)),
              activeThumbColor: AppTheme.emerald,
            ),
            child: settings.reminderEnabled ? _ReminderConfig(
              time: settings.reminderTime,
              days: settings.reminderDays,
              dayLabels: days,
              color: AppTheme.emerald,
              onTimeChanged: (t) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(reminderTime: t)),
              onDaysChanged: (d) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(reminderDays: d)),
            ) : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // Offene Fahrten Erinnerung
          _SectionCard(
            title: 'Offene Fahrten Erinnerung',
            trailing: Switch(
              value: settings.openReminderEnabled,
              onChanged: (v) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(openReminderEnabled: v)),
              activeThumbColor: Colors.red,
            ),
            child: settings.openReminderEnabled ? _ReminderConfig(
              time: settings.openReminderTime,
              days: settings.openReminderDays,
              dayLabels: days,
              color: Colors.red,
              onTimeChanged: (t) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(openReminderTime: t)),
              onDaysChanged: (d) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(openReminderDays: d)),
            ) : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // Export & Import
          _SectionCard(
            title: 'Daten & Export',
            child: Column(children: [
              Row(children: [
                Expanded(child: _ExportButton(icon: Icons.table_chart_outlined, label: 'CSV', onTap: () => exportToCsv(context, allTrips))),
                const SizedBox(width: 8),
                Expanded(child: _ExportButton(icon: Icons.picture_as_pdf_outlined, label: 'PDF', onTap: () => exportToPdf(context, allTrips))),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _ExportButton(
                  icon: Icons.upload_file_outlined,
                  label: 'JSON importieren',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen())),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showVehicleForm(BuildContext context, WidgetRef ref, Vehicle? vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleForm(
        initialData: vehicle,
        onSave: (v) {
          if (vehicle != null) {
            ref.read(vehiclesProvider.notifier).updateVehicle(vehicle.id, v.copyWith(id: vehicle.id));
          } else {
            ref.read(vehiclesProvider.notifier).addVehicle(v);
          }
        },
      ),
    );
  }

  void _confirmDeleteVehicle(BuildContext context, WidgetRef ref, Vehicle v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrzeug löschen'),
        content: Text('${v.name} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(onPressed: () { Navigator.pop(ctx); ref.read(vehiclesProvider.notifier).deleteVehicle(v.id); }, child: const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            ?trailing,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ExportButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ReminderConfig extends StatelessWidget {
  final String time;
  final List<int> days;
  final List<String> dayLabels;
  final Color color;
  final void Function(String) onTimeChanged;
  final void Function(List<int>) onDaysChanged;

  const _ReminderConfig({required this.time, required this.days, required this.dayLabels, required this.color, required this.onTimeChanged, required this.onDaysChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Uhrzeit', style: TextStyle(fontSize: 13)),
        subtitle: Text(time),
        trailing: const Icon(Icons.access_time_outlined),
        onTap: () async {
          final parts = time.split(':');
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 18, minute: int.tryParse(parts[1]) ?? 0),
          );
          if (t != null) onTimeChanged('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
        },
      ),
      Wrap(
        spacing: 6,
        children: List.generate(7, (i) {
          final selected = days.contains(i);
          return ActionChip(
            label: Text(dayLabels[i], style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
            backgroundColor: selected ? color : null,
            onPressed: () {
              final newDays = List<int>.from(days);
              if (selected) { newDays.remove(i); } else { newDays.add(i); }
              newDays.sort();
              onDaysChanged(newDays);
            },
          );
        }),
      ),
    ]);
  }
}
