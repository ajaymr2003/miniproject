import 'dart:async';
import 'dart:convert';
// 1. Use the new, correct import
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

/// A service to interact with the Firebase AI (Gemini) models.
class AiRecommendationService {
  AiRecommendationService._();
  static final AiRecommendationService instance = AiRecommendationService._();

  late final GenerativeModel _model;

  Future<void> initialize() async {
    print("Initializing AI Recommendation Service using Firebase AI Logic...");
    
    // 2. Use the new initialization method for the Gemini Developer API path
    // Note: We use a known stable model name. The docs sometimes show preview names.
    _model = FirebaseAI.googleAI().generativeModel(model: 'gemini-1.5-flash-latest');
    
    print("AI Service Initialized with model: gemini-1.5-flash-latest");
  }

  Future<Map<String, String>?> getEVStationRecommendation({
    required String userVehicle,
    required double batteryLevel,
    required List<StationInfo> nearbyStations,
  }) async {
    print("Calling Firebase AI API for recommendation...");
    final prompt = _buildPrompt(userVehicle, batteryLevel, nearbyStations);

    try {
      final response = await _generateResponse(_model, prompt);
      return response;
    } catch (e) {
      print("AI model failed to generate content: $e");
      // Re-throw the error so the UI shows a detailed message
      throw Exception('AI model failed: ${e.toString()}');
    }
  }

  Future<Map<String, String>> _generateResponse(
      GenerativeModel model, String prompt) async {
    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);
    final responseText = response.text;
    
    print("--- RAW AI RESPONSE ---");
    print(responseText);
    print("-----------------------");

    if (responseText != null && responseText.isNotEmpty) {
      String cleanedText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final decodedJson = jsonDecode(cleanedText) as Map<String, dynamic>;
      
      if (decodedJson.containsKey('recommendation') && decodedJson.containsKey('reason')) {
        return {
          'recommendation': decodedJson['recommendation'] as String,
          'reason': decodedJson['reason'] as String,
        };
      }
    }
    throw Exception("AI returned an invalid or empty response.");
  }

  String _buildPrompt(String userVehicle, double batteryLevel, List<StationInfo> nearbyStations) {
    return """
    You are an expert AI assistant for an EV charging app. Your goal is to recommend the single best charging station for a user.
    Analyze the user's situation and the list of nearby stations, then provide a recommendation.

    User's Situation:
    - Vehicle: $userVehicle
    - Current Battery: ${batteryLevel.toStringAsFixed(0)}%

    Nearby Stations Data (in JSON format):
    ${jsonEncode(nearbyStations.map((s) => s.toJson()).toList())}

    Your Task:
    1. Prioritize stations with available slots. A station with 0 available slots is a bad choice unless the waiting time is very short.
    2. Strongly prefer stations with zero or low waiting times.
    3. Consider the distance. If the user's battery is low, closer is better.
    4. Faster charging speeds (higher kW) are highly desirable.
    5. Balance all these factors to find the OPTIMAL station. For example, a slightly farther station with instant availability and a fast charger might be better than a closer one with a long wait.

    Output Format:
    Respond ONLY with a valid JSON object containing two keys: "recommendation" (the name of the best station) and "reason" (a short, user-friendly explanation for your choice). Do not include any other text, markdown, or explanations outside of the JSON object.

    Example Response:
    {
      "recommendation": "Green Power Hub",
      "reason": "It's very close by, has open slots right now, and offers fast charging to get you back on the road quickly."
    }
    """;
  }
}