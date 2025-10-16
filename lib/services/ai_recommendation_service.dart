// lib/services/ai_recommendation_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_database/firebase_database.dart';
// --- MODIFICATION: Import the StationWithDistance class ---
import 'package:miniproject/pages/evuser/widgets/nearby_stations_widget.dart';

// Helper class to structure charging station data for the AI prompt.
class StationInfo {
  final String name;
  final double distanceKm;
  final int availableSlots;
  final int waitingTime;
  final int chargerSpeed;

  StationInfo({
    required this.name,
    required this.distanceKm,
    required this.availableSlots,
    required this.waitingTime,
    required this.chargerSpeed,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'distance_km': distanceKm,
      'available_slots': availableSlots,
      'waiting_time_min': waitingTime,
      'charger_speed_kw': chargerSpeed,
    };
  }
}

class AiRecommendationService {
  AiRecommendationService._();
  static final AiRecommendationService instance = AiRecommendationService._();
  
  late final GenerativeModel _model;

  Future<void> initialize() async {
    _model = FirebaseAI.googleAI().generativeModel(model: 'gemini-flash-latest');
    print("AI Service Initialized with model: gemini-1.5-flash-latest");
  }

  // --- MAJOR MODIFICATION: The service now fetches RTDB data itself ---
  Future<Map<String, dynamic>?> getEVStationRecommendation({
    required String userVehicle,
    required double batteryLevel,
    // The method now accepts the full StationWithDistance object to get IDs
    required List<StationWithDistance> nearbyStations,
  }) async {
    print("Calling Firebase AI with real-time slot data...");

    // This list will be populated with live data before being sent to the AI
    final List<StationInfo> stationsWithRealtimeStatus = [];

    for (final stationWithDist in nearbyStations) {
      // Get the station ID to query the Realtime Database
      final stationId = stationWithDist.id;
      final stationStatusRef = FirebaseDatabase.instance.ref('station_status/$stationId');
      
      int availableSlots = 0; // Default to 0 if no data is found
      try {
        final snapshot = await stationStatusRef.get();
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value;
          // The data in RTDB is a List of booleans (e.g., [true, false, false])
          if (data is List) {
            // Count how many slots are 'true' (available)
            availableSlots = data.where((slotStatus) => slotStatus == true).length;
          }
        }
      } catch (e) {
        print("Error fetching RTDB status for station $stationId: $e");
        // Continue with 0 available slots if there's an error
      }

      final stationData = stationWithDist.data;
      final List<dynamic> slotsMetadata = stationData['slots'] ?? [];
      int maxChargerSpeed = 0;
      if (slotsMetadata.isNotEmpty) {
        maxChargerSpeed = slotsMetadata
            .map<int>((s) => (s['powerKw'] as num?)?.toInt() ?? 0)
            .reduce((a, b) => a > b ? a : b);
      }

      // Create the final StationInfo object with the LIVE availableSlots count
      stationsWithRealtimeStatus.add(
        StationInfo(
          name: stationData['name'] ?? 'Unknown',
          distanceKm: stationWithDist.distanceInMeters / 1000,
          availableSlots: availableSlots, // <-- Using the real-time value
          waitingTime: (stationData['waitingTime'] as num?)?.toInt() ?? 0,
          chargerSpeed: maxChargerSpeed,
        ),
      );
    }
    
    final prompt = _buildPrompt(userVehicle, batteryLevel, stationsWithRealtimeStatus);

    try {
      final response = await _generateResponse(_model, prompt);
      return response;
    } catch (e) {
      print("AI model failed to generate content: $e");
      throw Exception('AI model failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> _generateResponse(
      GenerativeModel model, String prompt) async {
    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);
    final responseText = response.text;
    
    print("--- RAW AI RANKING RESPONSE ---");
    print(responseText);
    print("-----------------------------");

    if (responseText == null || responseText.isEmpty) {
      throw Exception("AI returned an empty response.");
    }

    try {
      String cleanedText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final decodedJson = jsonDecode(cleanedText);

      if (decodedJson is! Map<String, dynamic>) {
        throw FormatException("AI response is not a valid JSON object.");
      }
      
      final reason = decodedJson['reason'];
      final recommendations = decodedJson['recommendations'];

      if (reason is! String || recommendations is! List) {
        throw FormatException("AI response is missing required keys ('reason', 'recommendations') or they have the wrong type.");
      }
      
      return {
        'reason': reason,
        'recommendations': recommendations,
      };

    } on FormatException catch(e) {
      print("JSON Parsing Error: $e");
      throw Exception("AI returned data in an unexpected format. Please try again.");
    }
  }

  String _buildPrompt(String userVehicle, double batteryLevel, List<StationInfo> nearbyStations) {
    return """
    You are an expert AI assistant for an EV charging app. Your goal is to recommend the top 3 best charging stations for a user in ranked order.
    Analyze the user's situation and the list of nearby stations, then provide a ranked recommendation.

    User's Situation:
    - Vehicle: $userVehicle
    - Current Battery: ${batteryLevel.toStringAsFixed(0)}%

    Nearby Stations Data (in JSON format):
    ${jsonEncode(nearbyStations.map((s) => s.toJson()).toList())}

    Your Task:
    1. Identify the top 3 best stations based on a balance of factors.
    2. Primary factors are: available slots (higher is better, 0 is very bad), waiting time (lower is better), and distance (closer is better, especially for low battery).
    3. Secondary factor: charger speed (higher kW is better).
    4. Rank the top 3 stations from best (#1) to third best (#3).
    5. IMPORTANT: Ensure the station names in your response's "recommendations" array EXACTLY MATCH the names from the input data.

    Output Format:
    Respond ONLY with a valid JSON object. The object must contain a "reason" key with a general summary of your choices, and a "recommendations" key which is an array of strings (the exact names of the top 3 stations in ranked order).

    Example Response:
    {
      "reason": "Based on your low battery, here are the closest stations with available slots and fast chargers.",
      "recommendations": ["Green Power Hub", "ChargePoint Central", "EV Fast Lane"]
    }
    """;
  }
}