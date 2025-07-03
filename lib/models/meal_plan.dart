import 'package:cloud_firestore/cloud_firestore.dart';

class MealPlan {
  final String id;
  final String userId;
  final DateTime date;
  final Map<String, MealEntry> meals;

  MealPlan({
    required this.id,
    required this.userId,
    required this.date,
    required this.meals,
  });

  // Factory constructor to create a MealPlan from a Map (Firestore document)
  factory MealPlan.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    Map<String, MealEntry> meals = {};
    Map<String, dynamic> mealsData = data['meals'] ?? {};
    
    mealsData.forEach((mealType, mealData) {
      if (mealData != null) {
        meals[mealType] = MealEntry.fromMap(mealData);
      }
    });

    return MealPlan(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      meals: meals,
    );
  }

  // Convert MealPlan to Map for Firestore
  Map<String, dynamic> toMap() {
    Map<String, dynamic> mealsMap = {};
    
    meals.forEach((mealType, mealEntry) {
      mealsMap[mealType] = mealEntry.toMap();
    });
    
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'meals': mealsMap,
    };
  }

  // Helper method to get a specific date format as string (YYYY-MM-DD)
  String get dateId => date.toIso8601String().split('T')[0];
  
  // Helper method to check if there's a meal for a specific type
  bool hasMeal(String mealType) => meals.containsKey(mealType);
  
  // Create a copy of MealPlan with optional new values
  MealPlan copyWith({
    String? id,
    String? userId,
    DateTime? date,
    Map<String, MealEntry>? meals,
  }) {
    return MealPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      meals: meals ?? Map.from(this.meals),
    );
  }
  
  // Add or update a meal entry
  MealPlan addMeal(String mealType, MealEntry entry) {
    final updatedMeals = Map<String, MealEntry>.from(meals);
    updatedMeals[mealType] = entry;
    return copyWith(meals: updatedMeals);
  }
  
  // Remove a meal entry
  MealPlan removeMeal(String mealType) {
    final updatedMeals = Map<String, MealEntry>.from(meals);
    updatedMeals.remove(mealType);
    return copyWith(meals: updatedMeals);
  }
}

class MealEntry {
  final String recipeName;
  final Map<String, dynamic> recipeDetails;
  final bool isCustom; // If true, this is a custom entry, not from recipe database

  MealEntry({
    required this.recipeName,
    required this.recipeDetails,
    this.isCustom = false,
  });

  // Factory constructor from map
  factory MealEntry.fromMap(Map<String, dynamic> data) {
    return MealEntry(
      recipeName: data['recipeName'] ?? '',
      recipeDetails: data['recipeDetails'] ?? {},
      isCustom: data['isCustom'] ?? false,
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'recipeName': recipeName,
      'recipeDetails': recipeDetails,
      'isCustom': isCustom,
    };
  }
} 