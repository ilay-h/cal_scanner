
import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/food_item.dart';

class FoodService {
  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<Either<String, FoodItem>> detectFoodAndCalories(
    File imageFile,
  ) async {
    try {
      if (!imageFile.existsSync()) {
        return Left('File not found');
      }

      if (_apiKey.isEmpty) {
        return Left('Gemini API key is missing');
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final extension = imageFile.path.toLowerCase();
      final mimeType = extension.endsWith('.png')
          ? 'image/png'
          : extension.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent',
        ),
        headers: {
          'x-goog-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'Analyze this food image. Estimate calories, '
                      'protein, carbs and fat. Return JSON only with '
                      'these fields: name, calories, protein, carbs, fat. '
                      'Use numeric values for all nutrition fields. '
                      'If the food is unclear, give your best estimate.'
                },
                {
                  'inline_data': {
                    'mime_type': mimeType,
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
          }
        }),
      );

      if (response.statusCode != 200) {
        return Left('Gemini API error: ${response.body}');
      }

      final data = jsonDecode(response.body);

      final parts = data['candidates'][0]['content']['parts'];

      final output = parts
          .where((part) => part['text'] != null)
          .map((part) => part['text'] as String)
          .join();

      final foodData = jsonDecode(output);

      return Right(
        FoodItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: foodData['name'],
          calories: (foodData['calories'] as num).toDouble(),
          protein: (foodData['protein'] as num).toDouble(),
          carbs: (foodData['carbs'] as num).toDouble(),
          fat: (foodData['fat'] as num).toDouble(),
          quantity: 100.0,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      return Left('Failed to detect food: ${e.toString()}');
    }
  }
}
