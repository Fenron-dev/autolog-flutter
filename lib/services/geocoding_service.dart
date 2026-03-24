import 'package:geocoding/geocoding.dart';
import '../models/models.dart';

class GeocodingService {
  GeocodingService._();
  static final instance = GeocodingService._();

  /// Reverse-geocode [lat]/[lng] into a human-readable address string.
  /// Returns null on failure (no network, no result, etc.).
  Future<String?> getAddress(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      return _formatPlacemark(p);
    } catch (_) {
      return null;
    }
  }

  /// Try to match a resolved address against the customer list.
  /// Returns the best matching [Customer] or null.
  Customer? matchCustomer(String address, List<Customer> customers) {
    if (address.isEmpty || customers.isEmpty) return null;

    final addrLower = address.toLowerCase();

    // 1) Exact address match
    for (final c in customers) {
      if (c.address.isNotEmpty &&
          c.address.toLowerCase() == addrLower) {
        return c;
      }
    }

    // 2) Customer address is contained in the resolved address (or vice versa).
    //    E.g. customer has "Musterstraße 1, Berlin" and geocoding returns
    //    "Musterstraße 1, 12345 Berlin, Deutschland".
    Customer? bestMatch;
    int bestScore = 0;

    for (final c in customers) {
      if (c.address.isEmpty) continue;
      final custLower = c.address.toLowerCase();

      // Check both directions
      if (addrLower.contains(custLower) || custLower.contains(addrLower)) {
        // Score by how many parts match
        final score = _matchScore(addrLower, custLower);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = c;
        }
      }
    }

    if (bestMatch != null) return bestMatch;

    // 3) Fuzzy: check if street + number match (most important part)
    for (final c in customers) {
      if (c.address.isEmpty) continue;
      final custStreet = _extractStreet(c.address.toLowerCase());
      final addrStreet = _extractStreet(addrLower);
      if (custStreet.isNotEmpty &&
          addrStreet.isNotEmpty &&
          custStreet == addrStreet) {
        return c;
      }
    }

    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatPlacemark(Placemark p) {
    final parts = <String>[];
    // Street + house number
    final street = [p.street].where((s) => s != null && s.isNotEmpty).join(' ');
    if (street.isNotEmpty) parts.add(street);
    // Postal code + city
    final city = [p.postalCode, p.locality]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    if (city.isNotEmpty) parts.add(city);
    return parts.join(', ');
  }

  /// Count how many comma-separated parts of [a] appear in [b] and vice versa.
  int _matchScore(String a, String b) {
    final partsA = a.split(RegExp(r'[,\s]+')).where((s) => s.length > 2).toSet();
    final partsB = b.split(RegExp(r'[,\s]+')).where((s) => s.length > 2).toSet();
    return partsA.intersection(partsB).length;
  }

  /// Extract "street number" from an address string (first comma-separated part).
  String _extractStreet(String address) {
    final parts = address.split(',');
    return parts.isNotEmpty ? parts.first.trim() : '';
  }
}
