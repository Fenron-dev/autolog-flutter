import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/date_utils.dart' as du;
import '../widgets/trip_card.dart';

enum TimeFilter { week, month, year, all }

class HistoryScreen extends ConsumerStatefulWidget {
  final void Function(Trip) onEditTrip;
  const HistoryScreen({super.key, required this.onEditTrip});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  TimeFilter _filter = TimeFilter.week;
  Set<String> _selectedIds = {};
  bool _selectMode = false;
  bool _bulkBilled = false;
  bool _bulkLogged = false;
  final _scrollController = ScrollController();
  bool _showScrollButtons = false;

  // Cached filter results – invalidated when trips or filter change
  List<Trip>? _cachedTrips;
  int _cachedTotalCompleted = 0;
  double _cachedTotalKm = 0;
  Object? _lastTripsIdentity;
  TimeFilter? _lastFilter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 200;
      if (show != _showScrollButtons) setState(() => _showScrollButtons = show);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Returns filtered+sorted trips, using cache when possible.
  ({List<Trip> trips, int totalCompleted, double totalKm}) _getFilteredTrips(List<Trip> activeTrips) {
    // Cache hit: same trip list identity and same filter
    if (identical(activeTrips, _lastTripsIdentity) && _filter == _lastFilter && _cachedTrips != null) {
      return (trips: _cachedTrips!, totalCompleted: _cachedTotalCompleted, totalKm: _cachedTotalKm);
    }
    _lastTripsIdentity = activeTrips;
    _lastFilter = _filter;

    final completed = activeTrips.where((t) => t.status == TripStatus.completed).toList();
    _cachedTotalCompleted = completed.length;

    List<Trip> filtered;
    if (_filter == TimeFilter.all) {
      filtered = completed;
    } else {
      final now = DateTime.now();
      filtered = completed.where((t) {
        final d = DateTime.tryParse(t.date);
        if (d == null) return false;
        return switch (_filter) {
          TimeFilter.week => du.isSameWeek(d, now),
          TimeFilter.month => du.isSameMonth(d, now),
          TimeFilter.year => du.isSameYear(d, now),
          TimeFilter.all => true,
        };
      }).toList();
    }
    filtered.sort((a, b) {
      final dc = b.date.compareTo(a.date);
      return dc != 0 ? dc : b.startTime.compareTo(a.startTime);
    });
    _cachedTrips = filtered;
    _cachedTotalKm = filtered.fold(0.0, (s, t) => s + t.distanceKm);
    return (trips: filtered, totalCompleted: _cachedTotalCompleted, totalKm: _cachedTotalKm);
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds = {};
      _bulkBilled = false;
      _bulkLogged = false;
    });
  }

  void _applyBulk() {
    if (_selectedIds.isEmpty) return;
    ref.read(tripsProvider.notifier).bulkUpdate(
      _selectedIds.toList(),
      isBilled: _bulkBilled ? true : null,
      isLogged: _bulkLogged ? true : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedIds.length} Fahrten aktualisiert.')),
    );
    _exitSelectMode();
  }

  void _scrollToTop() {
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ── Reverse Geocoding for existing trips ────────────────────────────────

  Future<void> _geocodeTripsWithoutAddress(List<Trip> trips) async {
    final withoutAddr = trips.where((t) =>
        t.destinationAddress.isEmpty &&
        t.destinationName.startsWith('Erkannte Fahrt')).toList();

    if (withoutAddr.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Fahrten ohne Adresse gefunden.')),
        );
      }
      return;
    }

    // Show the hint that we're parsing addresses from notes
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Versuche ${withoutAddr.length} Adressen aufzulösen…'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Currently we can't reverse-geocode old trips since we don't store
    // lat/lng in the Trip model. But we can offer to geocode the current
    // address field by looking up what is in the notes (Start: ...).
    // For now, inform the user.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hinweis: Alte Fahrten ohne GPS-Koordinaten können nicht '
            'nachträglich aufgelöst werden. Neue Fahrten speichern die '
            'Adresse automatisch.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTrips = ref.watch(tripsProvider.select((s) => s.activeTrips));
    final vehicles = ref.watch(vehiclesProvider);
    final vehicleMap = {for (final v in vehicles) v.id: v};
    final result = _getFilteredTrips(activeTrips);
    final trips = result.trips;
    final totalCompleted = result.totalCompleted;
    final totalKm = result.totalKm;

    return Scaffold(
      appBar: _selectMode
          ? AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.close), onPressed: _exitSelectMode),
              title: Text('${_selectedIds.length} ausgewählt'),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _selectedIds = trips
                      .where((t) => t.type == TripType.business)
                      .map((t) => t.id)
                      .toSet()),
                  child: const Text('Alle'),
                ),
              ],
            )
          : AppBar(
              title: const Text('Historie',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    if (v == 'geocode') _geocodeTripsWithoutAddress(trips);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'geocode',
                      child: ListTile(
                        leading: Icon(Icons.location_searching, size: 20),
                        title: Text('Adressen auflösen',
                            style: TextStyle(fontSize: 14)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: Stack(
        children: [
          Column(
            children: [
              // Filter chips + count
              if (!_selectMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: TimeFilter.values.map((f) {
                          final label = switch (f) {
                            TimeFilter.week => 'Woche',
                            TimeFilter.month => 'Monat',
                            TimeFilter.year => 'Jahr',
                            TimeFilter.all => 'Alle',
                          };
                          final selected = _filter == f;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: FilledButton.tonal(
                                onPressed: () =>
                                    setState(() => _filter = f),
                                style: FilledButton.styleFrom(
                                  backgroundColor: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  foregroundColor: selected
                                      ? Colors.white
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(label,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                      // Entry count
                      Row(
                        children: [
                          Text(
                            '${trips.length} Einträge'
                            '${_filter != TimeFilter.all ? ' (gesamt: $totalCompleted)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${totalKm.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),

              // Trip list
              Expanded(
                child: trips.isEmpty
                    ? Center(
                        child: Text(
                        'Keine Fahrten in diesem Zeitraum.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                            16, 0, 16, _selectMode ? 72 : 80),
                        itemCount: trips.length,
                        itemBuilder: (ctx, i) {
                          final trip = trips[i];
                          final selected = _selectedIds.contains(trip.id);
                          return GestureDetector(
                            onLongPress: () {
                              if (!_selectMode) {
                                setState(() {
                                  _selectMode = true;
                                  if (trip.type == TripType.business) {
                                    _selectedIds.add(trip.id);
                                  }
                                });
                              }
                            },
                            onTap: _selectMode
                                ? () {
                                    if (trip.type != TripType.business) return;
                                    setState(() {
                                      if (selected) {
                                        _selectedIds.remove(trip.id);
                                        if (_selectedIds.isEmpty) {
                                          _exitSelectMode();
                                        }
                                      } else {
                                        _selectedIds.add(trip.id);
                                      }
                                    });
                                  }
                                : null,
                            child: Stack(
                              children: [
                                TripCard(
                                  trip: trip,
                                  vehicleMap: vehicleMap,
                                  onEdit: _selectMode
                                      ? () {}
                                      : () => widget.onEditTrip(trip),
                                  onDelete: _selectMode
                                      ? () {}
                                      : () =>
                                          _confirmDelete(context, ref, trip),
                                  onReturnTrip: _selectMode
                                      ? () {}
                                      : () => ref
                                          .read(tripsProvider.notifier)
                                          .addReturnTrip(trip),
                                  onToggle: _selectMode
                                      ? (a, b) {}
                                      : (field, val) => ref
                                          .read(tripsProvider.notifier)
                                          .toggleField(trip.id, field, val),
                                ),
                                if (_selectMode &&
                                    trip.type == TripType.business)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IgnorePointer(
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: selected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: selected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .outline,
                                            width: 2,
                                          ),
                                        ),
                                        child: selected
                                            ? const Icon(Icons.check,
                                                color: Colors.white, size: 14)
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Bulk action bar
              if (_selectMode)
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SafeArea(
                    top: false,
                    child: Row(children: [
                      FilterChip(
                        label: const Text('Abgerechnet',
                            style: TextStyle(fontSize: 12)),
                        selected: _bulkBilled,
                        onSelected: (v) => setState(() => _bulkBilled = v),
                        selectedColor: Colors.green.shade100,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Eingetragen',
                            style: TextStyle(fontSize: 12)),
                        selected: _bulkLogged,
                        onSelected: (v) => setState(() => _bulkLogged = v),
                        selectedColor: Colors.blue.shade100,
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed:
                            (_selectedIds.isEmpty ||
                                    (!_bulkBilled && !_bulkLogged))
                                ? null
                                : _applyBulk,
                        child: const Text('Anwenden'),
                      ),
                    ]),
                  ),
                ),
            ],
          ),

          // Scroll to top / bottom buttons
          if (_showScrollButtons && !_selectMode)
            Positioned(
              right: 12,
              bottom: 90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ScrollFab(
                    icon: Icons.keyboard_arrow_up,
                    onPressed: _scrollToTop,
                  ),
                  const SizedBox(height: 8),
                  _ScrollFab(
                    icon: Icons.keyboard_arrow_down,
                    onPressed: _scrollToBottom,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrt löschen'),
        content: const Text('Fahrt in den Papierkorb verschieben?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tripsProvider.notifier).deleteTrip(trip.id);
            },
            child:
                const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ScrollFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ScrollFab({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: FloatingActionButton.small(
        heroTag: null,
        onPressed: onPressed,
        backgroundColor:
            Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 2,
        child: Icon(icon, size: 20),
      ),
    );
  }
}
