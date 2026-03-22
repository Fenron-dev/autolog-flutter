import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');
final _fileDateFormat = DateFormat('yyyy-MM-dd');

/// CSV-Injection Schutz: Felder die mit Formel-Zeichen beginnen werden mit ' prefixed
String _sanitizeCsv(String value) {
  if (value.startsWith(RegExp(r'[=+\-@]'))) return "'$value";
  return value;
}

String _formatDate(String iso) {
  try { return _dateFormat.format(DateTime.parse(iso)); } catch (_) { return iso; }
}

Future<void> exportToCsv(BuildContext context, List<Trip> trips) async {
  final rows = <List<String>>[
    ['Datum', 'Startzeit', 'Endzeit', 'Ziel/Name', 'Adresse', 'Kilometer', 'Typ', 'Abgerechnet', 'Eingetragen', 'Notizen'],
    ...trips.where((t) => t.status == TripStatus.completed).map((t) => [
      _sanitizeCsv(t.date),
      _sanitizeCsv(t.startTime),
      _sanitizeCsv(t.endTime),
      _sanitizeCsv(t.destinationName),
      _sanitizeCsv(t.destinationAddress),
      t.distanceKm.toStringAsFixed(1),
      t.type == TripType.business ? 'Geschäftlich' : 'Privat',
      t.isBilled ? 'Ja' : 'Nein',
      t.isLogged ? 'Ja' : 'Nein',
      _sanitizeCsv(t.notes),
    ]),
  ];

  final csvData = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
  final date = _fileDateFormat.format(DateTime.now());
  final fileName = 'Fahrtenbuch_Export_$date.csv';

  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvData, encoding: utf8);
    await Share.shareXFiles([XFile(file.path)], text: 'Fahrtenbuch CSV Export');
    // Temp-Datei nach dem Teilen aufräumen
    await file.delete().catchError((_) => file);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $e')));
    }
  }
}

Future<void> exportToPdf(BuildContext context, List<Trip> trips) async {
  final completed = trips.where((t) => t.status == TripStatus.completed).toList();
  final doc = pw.Document();
  final date = _fileDateFormat.format(DateTime.now());

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (pw.Context ctx) => [
        pw.Header(
          level: 0,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Fahrtenbuch Export', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Erstellt am: ${_dateFormat.format(DateTime.now())} • ${completed.length} Fahrten', style: const pw.TextStyle(fontSize: 11)),
          ]),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Datum', 'Startzeit', 'Endzeit', 'Ziel', 'Distanz', 'Typ', 'Abgerechnet', 'Eingetragen', 'Notizen'],
          data: completed.map((t) => [
            _formatDate(t.date),
            t.startTime,
            t.endTime,
            t.destinationName,
            '${t.distanceKm.toStringAsFixed(1)} km',
            t.type == TripType.business ? 'Geschäftl.' : 'Privat',
            t.isBilled ? 'Ja' : 'Nein',
            t.isLogged ? 'Ja' : 'Nein',
            t.notes,
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
          rowDecoration: const pw.BoxDecoration(),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerHeight: 24,
          cellHeight: 20,
        ),
      ],
    ),
  );

  try {
    await Printing.sharePdf(bytes: await doc.save(), filename: 'Fahrtenbuch_Export_$date.pdf');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF-Export fehlgeschlagen: $e')));
    }
  }
}
