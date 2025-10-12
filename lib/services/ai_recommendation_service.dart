// lib/services/ai_recommendation_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';

// Helper class to structure charging station data.
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

  Future<Map<String, dynamic>?> getEVStationRecommendation({
    required String userVehicle,
    required double batteryLevel,
    required List<StationInfo> nearbyStations,
  }) async {
    print("Calling Firebase AI for a ranked recommendation...");
    final prompt = _buildPrompt(userVehicle, batteryLevel, nearbyStations);

    try {
      final response = await _generateResponse(_model, prompt);
      return response;
    } catch (e) {
      print("AI model failed to generate content: $e");
      throw Exception('AI model failed: ${e.toString()}');
    }
  }

  // --- ROBUSTNESS FIX: Added extensive try-catch and type checking ---
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

  // --- IMPROVED PROMPT ---
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