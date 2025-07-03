import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  final GenerativeModel _model;
  
  GeminiService() : _model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
    generationConfig: GenerationConfig(
      temperature: 0.7,
      topK: 40,
      topP: 0.95,
      maxOutputTokens: 1024,
    ),
  );

        

  Future<String> getRecipeFromPrompt(String prompt) async {
    try {
      print('Sending prompt to Gemini: $prompt');
      
      final content = [Content.text(prompt)];
      
      final response = await _model.generateContent(content);

      final result = response.text;
      print('Received response from Gemini: $result');
      
      if (result == null || result.isEmpty) {
        throw Exception('Empty response from Gemini');
      }
      
      return result;
    } catch (e, stackTrace) {
      print('Error in Gemini service: $e');
      print('Stack trace: $stackTrace');
      
      if (e.toString().contains('models/gemini-pro is not found')) {
        throw Exception('Invalid model name. Update to use correct model name: gemini-2.0-flash');
      } else if (e.toString().contains('models/gemini-1.0-pro is not found')) {
        throw Exception('Invalid model name. Update to use correct model name: gemini-2.0-flash');
      } else if (e.toString().contains('models/gemini-2.0-flash is not found')) {
        throw Exception('Invalid model name or API key. Please check configuration.');
      } else if (e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('Invalid API key or insufficient permissions. Get a new API key.');
      } else {
        throw Exception('Failed to get recipe: $e');
      }
    }
  }
} 