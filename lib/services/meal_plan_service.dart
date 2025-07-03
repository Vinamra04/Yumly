import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_plan.dart';
import '../models/inventory_item.dart';
import 'gemini_service.dart';

class MealPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiService _geminiService = GeminiService();

  // Get user's meal plan collection reference
  CollectionReference<Map<String, dynamic>> _getMealPlanRef() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('mealPlans');
  }

  // Stream of meal plans for a given week
  Stream<List<MealPlan>> getMealPlansForWeek(DateTime startOfWeek) {
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    
    return _getMealPlanRef()
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('date', isLessThan: Timestamp.fromDate(endOfWeek))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MealPlan.fromFirestore(doc))
              .toList();
        });
  }

  // Get a specific meal plan for a date
  Future<MealPlan?> getMealPlanForDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    
    try {
      final snapshot = await _getMealPlanRef()
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.parse(dateStr)))
          .where('date', isLessThan: Timestamp.fromDate(
              DateTime.parse(dateStr).add(const Duration(days: 1))))
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return MealPlan.fromFirestore(snapshot.docs.first);
      }
      
      // If no meal plan exists for this date, return null
      return null;
    } catch (e) {
      print('Error getting meal plan: $e');
      return null;
    }
  }

  // Save or update a meal plan
  Future<void> saveMealPlan(MealPlan mealPlan) async {
    try {
      final dateStr = mealPlan.dateId;
      final existingPlan = await getMealPlanForDate(mealPlan.date);
      
      if (existingPlan != null) {
        // Update existing meal plan
        await _getMealPlanRef().doc(existingPlan.id).update(mealPlan.toMap());
      } else {
        // Create new meal plan
        await _getMealPlanRef().add(mealPlan.toMap());
      }
    } catch (e) {
      print('Error saving meal plan: $e');
      throw Exception('Failed to save meal plan: $e');
    }
  }

  // Delete a meal plan
  Future<void> deleteMealPlan(String mealPlanId) async {
    await _getMealPlanRef().doc(mealPlanId).delete();
  }

  // Get recipe suggestions based on inventory items
  Future<List<Map<String, dynamic>>> getRecipeSuggestions(List<InventoryItem> inventoryItems, String mealType) async {
    try {
      final ingredients = inventoryItems.map((item) => item.name).join(', ');
      
      final prompt = '''Suggest 3 appropriate recipes for $mealType using some of these ingredients: $ingredients.
For each recipe, provide the following information in a structured format:
1. Name: [recipe name]
2. Description: [brief 1-2 sentence description]
3. Ingredients: [list each ingredient on a new line with quantities]
4. Instructions: [number each step and put each step on a new line]

Separate each recipe with three newlines.''';
      
      final response = await _geminiService.getRecipeFromPrompt(prompt);
      
      final recipeEntries = response.split('\n\n\n')
          .where((s) => s.isNotEmpty)
          .toList();
          
      List<Map<String, dynamic>> formattedResults = [];
      
      for (var entry in recipeEntries) {
        Map<String, dynamic> recipeMap = {};
        
        // Extract name
        final nameMatch = RegExp(r'Name:\s*(.+)').firstMatch(entry);
        if (nameMatch != null) {
          recipeMap['name'] = nameMatch.group(1)!.trim();
        }
        
        // Extract description
        final descMatch = RegExp(r'Description:\s*(.+(?:\n.+)*)(?=\nIngredients:|$)').firstMatch(entry);
        if (descMatch != null) {
          recipeMap['description'] = descMatch.group(1)!.trim();
        }
        
        // Extract ingredients
        final ingredMatch = RegExp(r'Ingredients:\s*(.+(?:\n.+)*)(?=\nInstructions:|$)').firstMatch(entry);
        if (ingredMatch != null) {
          recipeMap['ingredients'] = ingredMatch.group(1)!.trim();
        }
        
        // Extract instructions
        final instrMatch = RegExp(r'Instructions:\s*(.+(?:\n.+)*)').firstMatch(entry);
        if (instrMatch != null) {
          recipeMap['instructions'] = instrMatch.group(1)!.trim();
        }
        
        if (recipeMap.containsKey('name')) {
          formattedResults.add(recipeMap);
        }
      }
      
      return formattedResults;
    } catch (e) {
      print('Error getting recipe suggestions: $e');
      throw Exception('Failed to get recipe suggestions: $e');
    }
  }

  // Generate grocery list from meal plans and inventory
  Future<Map<String, dynamic>> generateGroceryList(
      List<MealPlan> mealPlans, List<InventoryItem> inventoryItems) async {
    try {
      // Collect all recipes from all meal plans
      final allMeals = <String, dynamic>{};
      for (var plan in mealPlans) {
        plan.meals.forEach((mealType, mealEntry) {
          if (!allMeals.containsKey(mealEntry.recipeName)) {
            allMeals[mealEntry.recipeName] = mealEntry.recipeDetails;
          }
        });
      }
      
      // Extract ingredients from recipes
      final recipeIngredients = <String>[];
      allMeals.forEach((name, details) {
        if (details.containsKey('ingredients')) {
          final ingredientsList = details['ingredients'].toString().split('\n');
          for (var ingredient in ingredientsList) {
            if (ingredient.trim().isNotEmpty) {
              // Extract just the ingredient name (not quantities)
              var cleanedIngredient = ingredient.trim().toLowerCase();
              if (cleanedIngredient.contains(' ')) {
                // Try to extract just the ingredient name by dropping quantities
                cleanedIngredient = cleanedIngredient.split(' ').sublist(1).join(' ');
              }
              recipeIngredients.add(cleanedIngredient);
            }
          }
        }
      });
      
      // Create list of inventory item names (lowercase for comparison)
      final inventoryNames = inventoryItems.map((item) => item.name.toLowerCase()).toList();
      
      // Find missing ingredients (those in recipes but not in inventory)
      final missingIngredients = recipeIngredients.where((ingredient) {
        return !inventoryNames.any((invName) => ingredient.contains(invName));
      }).toList();
      
      // Remove duplicates
      final uniqueMissingIngredients = missingIngredients.toSet().toList();
      
      // Generate a more accurate grocery list using AI
      final prompt = '''I have these recipes planned for my meals: ${allMeals.keys.join(', ')}.
My current inventory has: ${inventoryItems.map((i) => i.name).join(', ')}.
Generate a concise grocery list of items I need to buy. 
Group items by category (Produce, Dairy, Meat, etc.) and remove any duplicates.
Format the response as a simple categorized list without unnecessary text.''';
      
      try {
        final response = await _geminiService.getRecipeFromPrompt(prompt);
        
        // Parse the AI response to extract categories and items
        final groceryByCategory = <String, List<String>>{};
        
        String currentCategory = 'Uncategorized';
        groceryByCategory[currentCategory] = [];
        
        for (var line in response.split('\n')) {
          line = line.trim();
          if (line.isEmpty) continue;
          
          // Check if this is a category header
          if (line.endsWith(':') || 
              line.toUpperCase() == line || 
              RegExp(r'^[A-Z][\w\s]+:?$').hasMatch(line)) {
            currentCategory = line.replaceAll(':', '').trim();
            groceryByCategory[currentCategory] = [];
          } else if (line.startsWith('- ') || line.startsWith('• ')) {
            // This is a list item
            final item = line.replaceAll('- ', '').replaceAll('• ', '').trim();
            groceryByCategory[currentCategory]!.add(item);
          } else {
            // Just add it to the current category
            groceryByCategory[currentCategory]!.add(line);
          }
        }
        
        return {
          'ai_generated': groceryByCategory,
          'missing_ingredients': uniqueMissingIngredients,
        };
      } catch (e) {
        print('Error generating AI grocery list: $e');
        // Fall back to simple list
        return {'missing_ingredients': uniqueMissingIngredients};
      }
    } catch (e) {
      print('Error generating grocery list: $e');
      throw Exception('Failed to generate grocery list: $e');
    }
  }
} 