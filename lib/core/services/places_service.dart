import 'dart:convert';
import 'package:http/http.dart' as http;

/// Google Places Autocomplete for Chennai-biased location search.
class PlacesService {
  // Same API key as routing_service.dart and AndroidManifest
  static const String _apiKey = 'AIzaSyAt9FKYc6Pv3_IlmyHrMP-FjtMN7Q_oe5w';

  // Chennai lat/lng for location bias
  static const double _chennaiLat = 13.0827;
  static const double _chennaiLng = 80.2707;

  /// Returns a list of place suggestions matching [input].
  static Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().length < 2) return [];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&location=$_chennaiLat,$_chennaiLng'
      '&radius=50000'          // 50 km bias around Chennai
      '&strictbounds=false'
      '&components=country:in'
      '&language=en'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') return [];

      final predictions = data['predictions'] as List? ?? [];
      return predictions.map((p) {
        final map = p as Map<String, dynamic>;
        return PlaceSuggestion(
          placeId:     map['place_id'] as String? ?? '',
          mainText:    (map['structured_formatting']?['main_text'] ?? map['description']) as String,
          secondaryText: (map['structured_formatting']?['secondary_text'] ?? '') as String,
          fullText:    map['description'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });
}
