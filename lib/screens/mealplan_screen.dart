import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_plan.dart';
import '../models/inventory_item.dart';
import '../services/meal_plan_service.dart';
import '../services/inventory_service.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> with SingleTickerProviderStateMixin {
  // Services
  final MealPlanService _mealPlanService = MealPlanService();
  final InventoryService _inventoryService = InventoryService();
  
  // State variables
  late DateTime _selectedWeekStart;
  late TabController _tabController;
  int _selectedTabIndex = 0;
  
  // Meal plan data
  List<MealPlan> _weeklyMealPlans = [];
  List<InventoryItem> _inventoryItems = [];
  bool _isLoading = false;
  
  // Show grocery list flag
  bool _showGroceryList = false;
  Map<String, dynamic> _groceryList = {};
  
  // List of meal types
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
  
  @override
  void initState() {
    super.initState();
    
    // Start with current week (starting Monday)
    final now = DateTime.now();
    _selectedWeekStart = DateTime(
      now.year, 
      now.month,
      now.day - now.weekday + 1, // Go to Monday
    );
    
    // Create tab controller for days of the week
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    // Load this week's meal plans and inventory
    _loadWeeklyData();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    }
  }
  
  // Load weekly meal plans and inventory
  Future<void> _loadWeeklyData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get meal plans for the week
      _mealPlanService.getMealPlansForWeek(_selectedWeekStart)
        .listen((mealPlans) {
          setState(() {
            _weeklyMealPlans = mealPlans;
            _isLoading = false;
          });
        });
      
      // Get inventory items
      _inventoryService.getInventoryItems().listen((items) {
        setState(() {
          _inventoryItems = items;
        });
      });
    } catch (e) {
      print('Error loading weekly data: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading meal plans: $e')),
      );
    }
  }
  
  // Change week
  void _changeWeek(int weekOffset) {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(Duration(days: 7 * weekOffset));
      _tabController.index = 0; // Reset to first day
      _selectedTabIndex = 0;
      _loadWeeklyData();
    });
  }
  
  // Helper to get the meal plan for a specific date
  MealPlan? _getMealPlanForDate(DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];
    return _weeklyMealPlans.firstWhere(
      (plan) => plan.dateId == dateStr,
      orElse: () => MealPlan(
        id: '', 
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        date: date,
        meals: {},
      ),
    );
  }
  
  // Get the date for a specific tab index
  DateTime _getDateForTabIndex(int index) {
    return _selectedWeekStart.add(Duration(days: index));
  }
  
  // Helper to format date as weekday
  String _formatWeekday(DateTime date) {
    return DateFormat('EEE').format(date);
  }
  
  // Helper to format date as day/month
  String _formatDayMonth(DateTime date) {
    return DateFormat('d/M').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'Generate Grocery List',
            onPressed: _showGroceryList ? null : _generateGroceryList,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _showGroceryList 
          ? _buildGroceryListView() 
          : _buildWeeklyMealPlanView(),
    );
  }
  
  Widget _buildWeeklyMealPlanView() {
    return Column(
      children: [
        // Weekly navigation
        _buildWeekNavigator(),
        
        // Tabs for days of the week
        _buildDayTabs(),
        
        // Main content area with TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(7, (index) {
              final date = _getDateForTabIndex(index);
              final mealPlan = _getMealPlanForDate(date);
              return _buildDayMealPlan(date, mealPlan);
            }),
          ),
        ),
      ],
    );
  }
  
  Widget _buildWeekNavigator() {
    final startDateFormatted = DateFormat('MMM d').format(_selectedWeekStart);
    final endDate = _selectedWeekStart.add(const Duration(days: 6));
    final endDateFormatted = DateFormat('MMM d, yyyy').format(endDate);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => _changeWeek(-1),
            iconSize: 18,
          ),
          Text(
            '$startDateFormatted - $endDateFormatted',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => _changeWeek(1),
            iconSize: 18,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDayTabs() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        indicatorColor: Theme.of(context).colorScheme.primary,
        tabs: List.generate(7, (index) {
          final date = _getDateForTabIndex(index);
          final isToday = DateUtils.isSameDay(date, DateTime.now());
          
          return Tab(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatWeekday(date),
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: isToday ? BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ) : null,
                  child: Text(
                    _formatDayMonth(date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildDayMealPlan(DateTime date, MealPlan? mealPlan) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mealTypes.length,
      itemBuilder: (context, index) {
        final mealType = _mealTypes[index];
        final hasMeal = mealPlan != null && mealPlan.hasMeal(mealType);
        final mealEntry = hasMeal ? mealPlan!.meals[mealType] : null;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getMealTypeIcon(mealType),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      mealType,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (hasMeal && mealEntry != null)
                  _buildMealEntry(mealType, mealEntry, date)
                else
                  _buildEmptyMealSlot(mealType, date),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildMealEntry(String mealType, MealEntry mealEntry, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealEntry.recipeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (mealEntry.recipeDetails.containsKey('description'))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        mealEntry.recipeDetails['description'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showAddMealDialog(date, mealType, initialMeal: mealEntry),
              color: Theme.of(context).colorScheme.primary,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _removeMeal(date, mealType),
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildEmptyMealSlot(String mealType, DateTime date) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Meal'),
            onPressed: () => _showAddMealDialog(date, mealType),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.smart_toy, size: 18),
          label: const Text('Get Suggestions', style: TextStyle(fontSize: 12)),
          onPressed: _inventoryItems.isEmpty 
            ? null 
            : () => _showSuggestionsDialog(date, mealType),
        ),
      ],
    );
  }
  
  IconData _getMealTypeIcon(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return Icons.breakfast_dining;
      case 'Lunch':
        return Icons.lunch_dining;
      case 'Dinner':
        return Icons.dinner_dining;
      case 'Snacks':
        return Icons.fastfood;
      default:
        return Icons.restaurant;
    }
  }
  
  // Show dialog to add/edit a meal
  Future<void> _showAddMealDialog(DateTime date, String mealType, {MealEntry? initialMeal}) async {
    final TextEditingController nameController = TextEditingController(
      text: initialMeal?.recipeName ?? '',
    );
    
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> recipeDetails = initialMeal?.recipeDetails ?? {};
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${initialMeal == null ? 'Add' : 'Edit'} $mealType'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Recipe/Meal Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a meal name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recipe Details (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: recipeDetails['description'] ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Brief description of the meal',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    recipeDetails['description'] = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: recipeDetails['ingredients'] ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Ingredients',
                    hintText: 'List ingredients, one per line',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    recipeDetails['ingredients'] = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: recipeDetails['instructions'] ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    hintText: 'Recipe instructions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    recipeDetails['instructions'] = value;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final mealEntry = MealEntry(
                  recipeName: nameController.text.trim(),
                  recipeDetails: recipeDetails,
                  isCustom: true,
                );
                
                Navigator.of(context).pop();
                _saveMeal(date, mealType, mealEntry);
              }
            },
            child: Text(initialMeal == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }
  
  // Save meal to the meal plan
  Future<void> _saveMeal(DateTime date, String mealType, MealEntry mealEntry) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get existing meal plan or create a new one
      MealPlan mealPlan = _getMealPlanForDate(date) ?? MealPlan(
        id: '',
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        date: date,
        meals: {},
      );
      
      // Add or update the meal
      mealPlan = mealPlan.addMeal(mealType, mealEntry);
      
      // Save to Firestore
      await _mealPlanService.saveMealPlan(mealPlan);
      
      // Refresh data
      _loadWeeklyData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$mealType saved successfully')),
        );
      }
    } catch (e) {
      print('Error saving meal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving meal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Remove meal from plan
  Future<void> _removeMeal(DateTime date, String mealType) async {
    // Confirm with user
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $mealType'),
        content: Text('Are you sure you want to remove this $mealType from your meal plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get existing meal plan
      MealPlan? mealPlan = _getMealPlanForDate(date);
      
      if (mealPlan != null && mealPlan.hasMeal(mealType)) {
        // Remove the meal
        mealPlan = mealPlan.removeMeal(mealType);
        
        // If the meal plan is now empty and has an id, delete it
        if (mealPlan.meals.isEmpty && mealPlan.id.isNotEmpty) {
          await _mealPlanService.deleteMealPlan(mealPlan.id);
        } else {
          // Otherwise save the updated plan
          await _mealPlanService.saveMealPlan(mealPlan);
        }
        
        // Refresh data
        _loadWeeklyData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$mealType removed successfully')),
          );
        }
      }
    } catch (e) {
      print('Error removing meal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing meal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Show dialog with AI-generated meal suggestions
  Future<void> _showSuggestionsDialog(DateTime date, String mealType) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final suggestions = await _mealPlanService.getRecipeSuggestions(
        _inventoryItems, 
        mealType
      );
      
      if (!mounted) return;
      
      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No suggestions available')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$mealType Suggestions'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final recipe = suggestions[index];
                return InkWell(
                  onTap: () {
                    // When tapped, add this recipe to the meal plan
                    Navigator.of(context).pop();
                    _saveMeal(
                      date, 
                      mealType, 
                      MealEntry(
                        recipeName: recipe['name'] ?? 'Unknown Recipe',
                        recipeDetails: recipe,
                        isCustom: false,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe['name'] ?? 'Unknown Recipe',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (recipe['description'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              recipe['description'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error getting suggestions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting suggestions: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Generate grocery list
  Future<void> _generateGroceryList() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_weeklyMealPlans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No meals planned for this week')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final groceryList = await _mealPlanService.generateGroceryList(
        _weeklyMealPlans, 
        _inventoryItems
      );
      
      setState(() {
        _groceryList = groceryList;
        _showGroceryList = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error generating grocery list: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating grocery list: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Build the grocery list view
  Widget _buildGroceryListView() {
    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showGroceryList = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'Grocery List',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Grocery list content
        Expanded(
          child: _groceryList.isEmpty 
            ? const Center(child: Text('No items needed'))
            : _buildGroceryItems(),
        ),
      ],
    );
  }
  
  Widget _buildGroceryItems() {
    // Check if we have AI-generated categorized list
    if (_groceryList.containsKey('ai_generated')) {
      final categorizedList = _groceryList['ai_generated'] as Map<String, List<String>>;
      
      if (categorizedList.isEmpty) {
        return const Center(child: Text('No items needed'));
      }
      
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categorizedList.length,
        itemBuilder: (context, index) {
          final category = categorizedList.keys.elementAt(index);
          final items = categorizedList[category] ?? [];
          
          if (items.isEmpty) return const SizedBox.shrink();
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, itemIndex) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outline_blank, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(items[itemIndex])),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (_groceryList.containsKey('missing_ingredients')) {
      // Fallback to simple missing ingredients list
      final missingIngredients = _groceryList['missing_ingredients'] as List<dynamic>;
      
      if (missingIngredients.isEmpty) {
        return const Center(child: Text('No items needed'));
      }
      
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Missing Ingredients',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: missingIngredients.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outline_blank, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(missingIngredients[index].toString())),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return const Center(child: Text('No items needed'));
    }
  }
}
