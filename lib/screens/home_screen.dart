import 'package:flutter/material.dart';
import 'package:yumly/screens/recipe_screen.dart';
import 'package:yumly/screens/mealplan_screen.dart';
import 'package:yumly/screens/inventory_screen.dart';
import 'package:yumly/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/gemini_service.dart';
import '../services/inventory_service.dart';
import '../services/meal_plan_service.dart';
import '../models/inventory_item.dart';
import '../models/meal_plan.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      const HomeContentScreen(),
      const RecipeScreen(),
      const MealPlanScreen(),
      const InventoryScreen(),
      const SettingsScreen(),
    ]);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.secondary,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0, // No elevation, we're using the container shadow
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'Recipes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              label: 'Planner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({super.key});

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final InventoryService _inventoryService = InventoryService();
  final MealPlanService _mealPlanService = MealPlanService();
  final GeminiService _geminiService = GeminiService();
  final ScrollController _scrollController = ScrollController();
  
  List<InventoryItem> _expiringItems = [];
  List<Map<String, dynamic>> _suggestedRecipes = [];
  MealPlan? _todaysMealPlan;
  bool _isLoadingInventory = false;
  bool _isLoadingRecipes = false;
  bool _isLoadingMealPlan = false;
  String _userName = '';
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadExpiringItems();
    _loadTodaysMealPlan();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists && mounted) {
          setState(() {
            _userName = doc.data()?['name'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  Future<void> _loadExpiringItems() async {
    if (mounted) {
      setState(() {
        _isLoadingInventory = true;
      });
    }
    
    try {
      // Subscribe to expiring items stream
      _inventoryService.getInventoryItems().listen((items) {
        if (mounted) {
          // Filter to items expiring in next 7 days or already expired
          final expiring = items.where((item) => 
            item.isExpiringSoon || item.isExpired
          ).toList();
          
          // Sort by expiry date (closest first)
          expiring.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
          
          setState(() {
            _expiringItems = expiring;
            _isLoadingInventory = false;
          });
          
          // Generate recipe suggestions based on inventory
          if (items.isNotEmpty && _suggestedRecipes.isEmpty) {
            _generateRecipeSuggestions(items);
          }
        }
      });
    } catch (e) {
      print('Error loading expiring items: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load inventory data: $e';
          _isLoadingInventory = false;
        });
      }
    }
  }
  
  Future<void> _loadTodaysMealPlan() async {
    if (mounted) {
      setState(() {
        _isLoadingMealPlan = true;
      });
    }
    
    try {
      // Get today's date
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      
      // Get meal plan for today
      final mealPlan = await _mealPlanService.getMealPlanForDate(todayDateOnly);
      
      if (mounted) {
        setState(() {
          _todaysMealPlan = mealPlan;
          _isLoadingMealPlan = false;
        });
      }
    } catch (e) {
      print('Error loading today\'s meal plan: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load meal plan data: $e';
          _isLoadingMealPlan = false;
        });
      }
    }
  }
  
  Future<void> _generateRecipeSuggestions(List<InventoryItem> items) async {
    if (mounted) {
      setState(() {
        _isLoadingRecipes = true;
      });
    }
    
    try {
      // Get ingredient names
      final ingredients = items.map((item) => item.name).join(', ');
      
      // Generate recipe suggestions using Gemini
      final prompt = '''Based on these ingredients I have: $ingredients
Suggest 2 recipes I could make. For each recipe, provide:
1. Name: [recipe name]
2. Description: [brief 1-2 sentence description highlighting key ingredients]
3. Cooking time: [estimated time in minutes]
4. Difficulty: [Easy, Medium, or Hard]

Format the response as a structured list with clear recipe sections.''';

      final response = await _geminiService.getRecipeFromPrompt(prompt);
      
      // Parse the response to extract recipes
      final recipes = _parseRecipeSuggestions(response);
      
      if (mounted) {
        setState(() {
          _suggestedRecipes = recipes;
          _isLoadingRecipes = false;
        });
      }
    } catch (e) {
      print('Error generating recipe suggestions: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecipes = false;
        });
      }
    }
  }
  
  List<Map<String, dynamic>> _parseRecipeSuggestions(String response) {
    final List<Map<String, dynamic>> recipes = [];
    
    // Split the response by recipe sections
    final recipeBlocks = response.split(RegExp(r'\n\s*\n|Recipe \d+:|^\d+\.')).where((s) => s.trim().isNotEmpty).toList();
    
    for (var block in recipeBlocks) {
      final Map<String, dynamic> recipe = {};
      
      // Extract name
      final nameMatch = RegExp(r'Name:\s*(.+)').firstMatch(block);
      if (nameMatch != null) {
        recipe['name'] = nameMatch.group(1)!.trim();
      }
      
      // Extract description
      final descMatch = RegExp(r'Description:\s*(.+(?:\n.+)*)(?=\nCooking time:|$)').firstMatch(block);
      if (descMatch != null) {
        recipe['description'] = descMatch.group(1)!.trim();
      }
      
      // Extract cooking time
      final timeMatch = RegExp(r'Cooking time:\s*(.+)').firstMatch(block);
      if (timeMatch != null) {
        recipe['cookingTime'] = timeMatch.group(1)!.trim();
      }
      
      // Extract difficulty
      final difficultyMatch = RegExp(r'Difficulty:\s*(.+)').firstMatch(block);
      if (difficultyMatch != null) {
        recipe['difficulty'] = difficultyMatch.group(1)!.trim();
      }
      
      // If we have at least a name, add to results
      if (recipe.containsKey('name')) {
        // Generate a random color
        final random = Random();
        final colors = [
          const Color(0xFF5F0F40), // burgundy
          const Color(0xFF9A031E), // red
          const Color(0xFF0F4C5C), // teal
          const Color(0xFF3A5A40), // forest green
          const Color(0xFF2B2D42), // navy
        ];
        recipe['color'] = colors[random.nextInt(colors.length)];
        
        recipes.add(recipe);
      }
    }
    
    return recipes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          // Could implement scroll-based app bar effects here
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            // Reload all data when user pulls down to refresh
            await Future.wait([
              _loadExpiringItems(),
              _loadTodaysMealPlan(),
            ]);
            
            // Clear suggestions to regenerate them
            setState(() {
              _suggestedRecipes = [];
            });
            
            return;
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Scrollable App Bar
              _buildSliverAppBar(),
              
              // Welcome Banner
              _buildWelcomeBanner(),
              
              // Suggested Recipes Section
              if (_suggestedRecipes.isNotEmpty) 
                _buildSuggestedRecipesSection()
              else if (_isLoadingRecipes)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              
              // Expiring Ingredients Section
              _buildExpiringIngredientsSection(),
              
              // Ask YumlyBot Section
              _buildAskYumlyBotSection(),
              
              // Today's Meal Plan Section
              _buildTodaysMealPlanSection(),
              
              // Bottom Padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: Theme.of(context).colorScheme.primary,
      expandedHeight: 64,
      centerTitle: true,
      title: const Text(
        'Yumly',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cursive',
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {
            // Navigate to settings screen using the bottom navigation bar
            (context.findAncestorStateOfType<_HomeScreenState>())?._onItemTapped(4);
          },
        ),
      ],
    );
  }
  
  Widget _buildWelcomeBanner() {
    final theme = Theme.of(context);
    
    return SliverToBoxAdapter(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.background,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      'Welcome to Yumly!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userName.isNotEmpty
                          ? 'Hi $_userName, your personal kitchen assistant'
                          : 'Your personal kitchen assistant',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onBackground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestedRecipesSection() {
    final theme = Theme.of(context);
    
    return SliverToBoxAdapter(
      child: Container(
        color: theme.colorScheme.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Suggested for You',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (_isLoadingRecipes)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 260, // Increased from 250 to accommodate card with margins
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestedRecipes.length,
                itemBuilder: (context, index) {
                  final recipe = _suggestedRecipes[index];
                  return _buildSuggestedRecipeCard(
                    name: recipe['name'] ?? 'Recipe',
                    description: recipe['description'] ?? '',
                    cookingTime: recipe['cookingTime'] ?? '30 mins',
                    difficulty: recipe['difficulty'] ?? 'Medium',
                    color: recipe['color'] ?? const Color(0xFF5F0F40), // Default to burgundy
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSuggestedRecipeCard({
    required String name,
    required String description,
    required String cookingTime,
    required String difficulty,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      width: 180,
      height: 250, // Set a fixed height to prevent overflow
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe header with color
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Recipe details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Use minimum height required
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cookingTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        difficulty,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            Container(
              height: 36, // Fixed height for action buttons
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/recipes', arguments: name);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: color,
                      ),
                      child: const Text('View Recipe', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/mealplan');
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: color,
                      ),
                      child: const Text('Add to Plan', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpiringIngredientsSection() {
    final theme = Theme.of(context);
    
    if (_expiringItems.isEmpty && !_isLoadingInventory) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    return SliverToBoxAdapter(
      child: Container(
        color: theme.colorScheme.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expiring Soon',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  if (_isLoadingInventory)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            if (_isLoadingInventory && _expiringItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Loading ingredients...',
                    style: TextStyle(color: theme.colorScheme.onBackground),
                  ),
                ),
              )
            else
              SizedBox(
                height: 170,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _expiringItems.length,
                  itemBuilder: (context, index) => _buildExpiringItemCard(_expiringItems[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpiringItemCard(InventoryItem item) {
    final theme = Theme.of(context);
    final isExpired = item.isExpired;
    
    Color cardColor;
    Color textColor;
    Widget icon;
    
    if (isExpired) {
      cardColor = theme.colorScheme.error.withOpacity(0.1);
      textColor = theme.colorScheme.error;
      icon = Icon(Icons.warning, color: theme.colorScheme.error, size: 18);
    } else {
      cardColor = theme.colorScheme.secondary.withOpacity(0.1);
      textColor = theme.colorScheme.secondary;
      icon = Icon(Icons.access_time, color: theme.colorScheme.secondary, size: 18);
    }
    
    return Container(
      width: 150,
      height: 160, // Setting a specific height to contain all content
      margin: const EdgeInsets.only(right: 12, bottom: 4),
      child: Card(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Use minimum height required
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  icon,
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4), // Reduced space
              Text(
                'Quantity: ${item.quantity} ${item.unit}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onBackground,
                ),
                maxLines: 1, // Limit lines
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2), // Reduced space
              Text(
                'Expires: ${DateFormat('MMM dd, yyyy').format(item.expiryDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1, // Limit lines
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/recipes', arguments: item);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(double.infinity, 30),
                ),
                child: const Text(
                  'Use in Recipe',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAskYumlyBotSection() {
    final theme = Theme.of(context);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/recipes');
          },
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Ensure the column uses minimum height
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.smart_toy_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ask YumlyBot',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'What can I cook today?',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12), // Reduced height
                  ConstrainedBox( // Wrap the Wrap widget with constraints
                    constraints: const BoxConstraints(maxHeight: 80),
                    child: SingleChildScrollView( // Make it scrollable if needed
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPromptChip('Dinner under 30 min'),
                          _buildPromptChip('Using rice, tomato, and onion'),
                          _buildPromptChip('Healthy breakfast'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPromptChip(String label) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context, 
          '/recipes',
          arguments: label,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
  
  Widget _buildTodaysMealPlanSection() {
    final theme = Theme.of(context);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Meal Plan",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (_isLoadingMealPlan)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTodaysMealPlanCard(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTodaysMealPlanCard() {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d').format(today);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          
          // Meals listing
          if (_isLoadingMealPlan)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_todaysMealPlan != null && _todaysMealPlan!.meals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildMealTypeEntries('Breakfast'),
                  ..._buildMealTypeEntries('Lunch'),
                  ..._buildMealTypeEntries('Dinner'),
                  ..._buildMealTypeEntries('Snacks'),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No meals planned for today',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // View full plan button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                // Navigate to meal plan screen using the bottom navigation bar
                (context.findAncestorStateOfType<_HomeScreenState>())?._onItemTapped(2);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
              child: const Text('View Full Plan'),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildMealTypeEntries(String mealType) {
    final theme = Theme.of(context);
    
    if (_todaysMealPlan == null || !_todaysMealPlan!.hasMeal(mealType)) {
      return [];
    }
    
    final mealEntry = _todaysMealPlan!.meals[mealType]!;
    
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _getMealTypeIcon(mealType),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealType,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mealEntry.recipeName,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }
  
  Widget _getMealTypeIcon(String mealType) {
    final theme = Theme.of(context);
    IconData iconData;
    Color color;
    
    switch (mealType) {
      case 'Breakfast':
        iconData = Icons.breakfast_dining;
        color = theme.colorScheme.secondary;
        break;
      case 'Lunch':
        iconData = Icons.lunch_dining;
        color = theme.colorScheme.primary;
        break;
      case 'Dinner':
        iconData = Icons.dinner_dining;
        color = theme.colorScheme.tertiary;
        break;
      case 'Snacks':
        iconData = Icons.fastfood;
        color = theme.colorScheme.error;
        break;
      default:
        iconData = Icons.restaurant;
        color = theme.colorScheme.primary;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 20,
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final String title;
  final String cookTime;
  final String imageUrl;
  final String difficulty;
  final Color color;

  const _RecipeCard({
    required this.title,
    required this.cookTime,
    required this.imageUrl,
    required this.difficulty,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                '$imageUrl?w=400&q=80',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: color.withOpacity(0.2),
                    child: Icon(Icons.restaurant, size: 40, color: color),
                  );
                },
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.onBackground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cookTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        difficulty,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MealCard extends StatelessWidget {
  final MealSuggestion meal;

  const MealCard({
    super.key,
    required this.meal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/recipes'),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                meal.imageUrl,
                width: 160,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 160,
                    height: 200,
                    color: theme.colorScheme.primary,
                    child: const Icon(
                      Icons.restaurant,
                      size: 50,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    meal.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MealSuggestion {
  final String title;
  final String imageUrl;

  MealSuggestion({
    required this.title,
    required this.imageUrl,
  });
}
