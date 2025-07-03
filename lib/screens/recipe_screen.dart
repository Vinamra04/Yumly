import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import '../services/gemini_service.dart';
import '../services/inventory_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final InventoryService _inventoryService = InventoryService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  List<String> _suggestions = [];
  List<Map<String, String>> _searchResults = [];
  List<Map<String, String>> _inventoryBasedRecipes = [];
  List<Map<String, String>> _chatMessages = [];
  String _currentRecipe = '';
  bool _isLoading = false;
  bool _showSuggestions = false;
  bool _showSearchResults = false;
  bool _showChat = false;
  String? _error;
  bool _showInitialContent = true;
  
  // New state variables
  bool _showRecipeDetails = false;
  Map<String, String> _currentRecipeDetails = {};
  bool _isInventoryBasedRecipe = false;

  @override
  void initState() {
    super.initState();
    _testGeminiConnection();
  }

  Future<void> _testGeminiConnection() async {
    try {
      // Test the Gemini service with a very simple query
      await _geminiService.getRecipeFromPrompt('Hi');
      print('Gemini service connected successfully');
    } catch (e) {
      print('Error connecting to Gemini: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not connect to recipe service: ${e.toString().contains('Exception:') ? e.toString().split('Exception:').last.trim() : e.toString()}';
        });
        
        // Show a more helpful error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe service connection error. You may need to update your API key.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final prompt = 'Suggest 5 popular dishes or recipes that contain or are related to "$query". Return ONLY the dish names, one per line, nothing else.';
      print('Getting suggestions for: $query');
      final response = await _geminiService.getRecipeFromPrompt(prompt);
      
      if (mounted) {
        setState(() {
          _suggestions = response.split('\n')
              .where((s) => s.isNotEmpty)
              .take(5)
              .toList();
          _showSuggestions = _suggestions.isNotEmpty;
          _showInitialContent = false;
        });
      }
    } catch (e) {
      print('Error getting suggestions: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not get suggestions. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchRecipes(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _showSuggestions = false;
      _showSearchResults = true;
      _showInitialContent = false;
      _showRecipeDetails = false;
      _searchResults = [];
    });
    
    try {
      final prompt = 'Give me 5 popular recipes that contain or are related to "$query". For each recipe, provide the following information in clearly labeled sections:\n1. Name: [recipe name]\n2. Description: [brief 2-3 sentence description]\n3. Ingredients: [list each ingredient on a new line with quantities]\n4. Instructions: [number each step and put each step on a new line]\nSeparate each recipe with three newlines.';
      print('Searching recipes for: $query');
      final response = await _geminiService.getRecipeFromPrompt(prompt);
      
      if (mounted) {
        final recipeEntries = response.split('\n\n\n')
            .where((s) => s.isNotEmpty)
            .toList();
            
        List<Map<String, String>> formattedResults = [];
        
        for (var entry in recipeEntries) {
          Map<String, String> recipeMap = {};
          
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
        
        // If we don't have enough recipes, make another request for similar dishes
        if (formattedResults.length < 5) {
          try {
            final similarPrompt = 'Give me ${5 - formattedResults.length} recipes similar to "$query" but with different names. For each recipe, provide the following information in clearly labeled sections:\n1. Name: [recipe name]\n2. Description: [brief 2-3 sentence description]\n3. Ingredients: [list each ingredient on a new line with quantities]\n4. Instructions: [number each step and put each step on a new line]\nSeparate each recipe with three newlines.';
            
            final similarResponse = await _geminiService.getRecipeFromPrompt(similarPrompt);
            
            final similarEntries = similarResponse.split('\n\n\n')
                .where((s) => s.isNotEmpty)
                .toList();
                
            for (var entry in similarEntries) {
              Map<String, String> recipeMap = {};
              
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
              
              if (recipeMap.containsKey('name') && !formattedResults.any((r) => r['name'] == recipeMap['name'])) {
                formattedResults.add(recipeMap);
                if (formattedResults.length >= 5) break;
              }
            }
          } catch (e) {
            print('Error getting similar recipes: $e');
          }
        }
        
        setState(() {
          _searchResults = formattedResults;
        });
      }
    } catch (e) {
      print('Error searching recipes: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not find recipes. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getRecipesFromInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _inventoryBasedRecipes = [];
    });
    
    try {
      final items = await _inventoryService.getInventoryItems().first;
      
      if (items.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Your inventory is empty. Add some ingredients first!';
          });
          return;
        }
      }
      
      final ingredients = items.map((item) => item.name).join(', ');
      final prompt = 'I have these ingredients: $ingredients. Suggest 5 popular dishes I can make with these ingredients. For each recipe, provide the following information in clearly labeled sections:\n1. Name: [recipe name]\n2. Description: [brief description mentioning which ingredients match and which are missing]\n3. Ingredients: [list each ingredient on a new line with quantities, clearly mark ingredients as AVAILABLE or MISSING]\n4. Instructions: [number each step and put each step on a new line]\nSeparate each recipe with a blank line.';
      final response = await _geminiService.getRecipeFromPrompt(prompt);
      
      if (mounted) {
        final recipeEntries = response.split('\n\n\n')
            .where((s) => s.isNotEmpty)
            .toList();
            
        List<Map<String, String>> formattedResults = [];
        
        for (var entry in recipeEntries) {
          Map<String, String> recipeMap = {};
          
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
        
        setState(() {
          _inventoryBasedRecipes = formattedResults;
          _showSearchResults = true;
          _showInitialContent = false;
        });
      }
    } catch (e) {
      print('Error getting inventory-based recipes: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not get recipes from your ingredients. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _getRecipeWithInventoryIngredients(String recipeName) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final items = await _inventoryService.getInventoryItems().first;
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your inventory is empty. Add ingredients first!')),
        );
        setState(() => _isLoading = false);
        return;
      }
      
      final ingredients = items.map((item) => item.name).join(', ');
      final prompt = 'I want to make $recipeName with these ingredients I have: $ingredients. Provide a recipe for $recipeName in the following format:\n1. Name: $recipeName\n2. Description: [brief description]\n3. Ingredients: [list each ingredient on a new line with quantities. For EACH ingredient clearly mark it as either "AVAILABLE" or "MISSING". For each MISSING ingredient, check if there\'s a suitable substitute from my available ingredients list. If a substitute exists, write "SUBSTITUTE: [substitute ingredient]". If no substitute is available, write "NO SUBSTITUTE".]\n4. Instructions: [number each step and put each step on a new line]';
      
      final response = await _geminiService.getRecipeFromPrompt(prompt);
      
      if (mounted) {
        Map<String, String> recipeMap = {};
        
        // Extract name
        final nameMatch = RegExp(r'Name:\s*(.+)').firstMatch(response);
        if (nameMatch != null) {
          recipeMap['name'] = nameMatch.group(1)!.trim();
        }
        
        // Extract description
        final descMatch = RegExp(r'Description:\s*(.+(?:\n.+)*)(?=\nIngredients:|$)').firstMatch(response);
        if (descMatch != null) {
          recipeMap['description'] = descMatch.group(1)!.trim();
        }
        
        // Extract ingredients
        final ingredMatch = RegExp(r'Ingredients:\s*(.+(?:\n.+)*)(?=\nInstructions:|$)').firstMatch(response);
        if (ingredMatch != null) {
          recipeMap['ingredients'] = ingredMatch.group(1)!.trim();
        }
        
        // Extract instructions
        final instrMatch = RegExp(r'Instructions:\s*(.+(?:\n.+)*)').firstMatch(response);
        if (instrMatch != null) {
          recipeMap['instructions'] = instrMatch.group(1)!.trim();
        }
        
        if (recipeMap.containsKey('name')) {
          setState(() {
            _currentRecipeDetails = recipeMap;
            _showRecipeDetails = true;
            _showSearchResults = false;
            _isInventoryBasedRecipe = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get recipe details. Please try again.')),
          );
        }
      }
    } catch (e) {
      print('Error getting recipe with inventory ingredients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _sendChatMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _chatMessages.add({'user': message});
      _chatController.clear();
      _isLoading = true;
    });

    try {
      String prompt;
      if (_currentRecipe.isNotEmpty) {
        prompt = 'You are Yumly Bot, a helpful assistant that only discusses food recipes. User is asking about $message regarding the recipe for $_currentRecipe. Respond in a helpful, friendly tone. Keep answers brief (2-3 sentences). If they ask for a recipe, include ingredients and brief steps. Don\'t invent details not commonly associated with this dish. Focus ONLY on cooking and food.';
      } else {
        prompt = 'You are Yumly Bot, a helpful assistant that only discusses food recipes. User is asking about $message. Respond in a helpful, friendly tone. Keep answers brief (2-3 sentences). If they ask for a recipe, include ingredients and brief steps. Don\'t invent details not commonly associated with this dish. Focus ONLY on cooking and food.';
      }
      
      final response = await _geminiService.getRecipeFromPrompt(prompt);
      
      setState(() {
        _chatMessages.add({'bot': response});
        
        // If this is the first message and it's about a specific recipe
        if (_currentRecipe.isEmpty && 
            (message.toLowerCase().contains("recipe") || 
             message.toLowerCase().contains("make") || 
             message.toLowerCase().contains("cook"))) {
          _currentRecipe = message;
          
          // Check if we should suggest checking ingredients
          _checkIngredientsForCurrentRecipe();
        }
        
        // Auto-scroll to the bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      });
    } catch (e) {
      print('Error sending chat message: $e');
      setState(() {
        _chatMessages.add({
          'bot': 'Sorry, I had trouble understanding that. Please try again.'
        });
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _checkIngredientsForCurrentRecipe() async {
    if (_currentRecipe.isEmpty) return;
    
    try {
      final items = await _inventoryService.getInventoryItems().first;
      if (items.isEmpty) return;
      
      final ingredients = items.map((item) => item.name).join(', ');
      
      setState(() {
        _chatMessages.add({
          'bot': 'Would you like me to check if you have the ingredients for this recipe in your inventory?'
        });
      });
    } catch (e) {
      print('Error checking ingredients: $e');
    }
  }
  
  void _openChatWithRecipe(String recipeName) {
    setState(() {
      _showChat = true;
      _currentRecipe = recipeName;
      _showSuggestions = false;
      _showSearchResults = false;
      _showInitialContent = false;
      
      if (_chatMessages.isEmpty) {
        _chatMessages.add({
          'bot': 'Hi! I\'m Yumly Bot. What would you like to know about $recipeName?'
        });
      } else {
        _chatMessages.add({
          'bot': 'What would you like to know about $recipeName?'
        });
      }
    });
  }

  void _displayRecipeDetails(Map<String, String> recipe, bool isInventoryBased) {
    setState(() {
      _showSearchResults = false;
      _showRecipeDetails = true;
      _currentRecipeDetails = recipe;
      _isInventoryBasedRecipe = isInventoryBased;
    });
  }

  Widget _buildRecipeDetailsScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showRecipeDetails = false;
                    _showSearchResults = true;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                _currentRecipeDetails['name'] ?? 'Recipe Details',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Recipe content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentRecipeDetails['description'] != null) ...[
                  Text(
                    _currentRecipeDetails['description']!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                ],
                
                if (_currentRecipeDetails['ingredients'] != null) ...[
                  Text(
                    'Ingredients',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentRecipeDetails['ingredients']!.split('\n').length,
                    itemBuilder: (context, index) {
                      final ingredient = _currentRecipeDetails['ingredients']!.split('\n')[index];
                      if (ingredient.trim().isEmpty) return const SizedBox.shrink();
                      
                      Color textColor = Colors.black;
                      bool isAvailable = ingredient.contains('AVAILABLE');
                      bool isMissing = ingredient.contains('MISSING');
                      bool hasSubstitute = ingredient.contains('SUBSTITUTE:');
                      bool noSubstitute = ingredient.contains('NO SUBSTITUTE');
                      
                      if (isAvailable) {
                        textColor = const Color(0xFF66BB6A); // Avocado Green
                      } else if (isMissing) {
                        textColor = const Color(0xFFFF6F61); // Mild Coral
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    // Clean up the ingredient text by removing the status markers
                                    ingredient
                                        .replaceAll('AVAILABLE', '')
                                        .replaceAll('MISSING', '')
                                        .replaceAll('NO SUBSTITUTE', '')
                                        .replaceAll('SUBSTITUTE:', '')
                                        .replaceAll('  ', ' ')
                                        .trim(),
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: isAvailable ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isAvailable)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF66BB6A).withOpacity(0.2), // Avocado Green
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Available',
                                      style: TextStyle(
                                        color: Color(0xFF66BB6A), // Avocado Green
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (isMissing)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6F61).withOpacity(0.2), // Mild Coral
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Missing',
                                      style: TextStyle(
                                        color: Color(0xFFFF6F61), // Mild Coral
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (hasSubstitute) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.swap_horiz,
                                      size: 16,
                                      color: Color(0xFF2F7164), // Forest Teal
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Substitute: ${ingredient.split('SUBSTITUTE:').last.trim()}',
                                        style: const TextStyle(
                                          color: Color(0xFF2F7164), // Forest Teal
                                          fontStyle: FontStyle.italic,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (noSubstitute && isMissing) ...[
                              const SizedBox(height: 4),
                              const Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.do_not_disturb_alt,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'No substitute available',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                
                if (_currentRecipeDetails['instructions'] != null) ...[
                  Text(
                    'Instructions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentRecipeDetails['instructions']!.split('\n').length,
                    itemBuilder: (context, index) {
                      final instruction = _currentRecipeDetails['instructions']!.split('\n')[index];
                      if (instruction.trim().isEmpty) return const SizedBox.shrink();
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (instruction.contains(RegExp(r'^\d+\.')))
                              Text(
                                instruction.split('.')[0] + '.',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )
                            else
                              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                instruction.contains(RegExp(r'^\d+\.')) 
                                    ? instruction.substring(instruction.indexOf('.') + 1).trim() 
                                    : instruction,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Bottom actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (!_isInventoryBasedRecipe)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _getRecipeWithInventoryIngredients(_currentRecipeDetails['name'] ?? ''),
                    icon: const Icon(Icons.kitchen),
                    label: const Text('Use ingredients from your kitchen'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _openChatWithRecipe(_currentRecipeDetails['name'] ?? '');
                    },
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Have questions?'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        elevation: 2,
        actions: [
          if (_showChat || _showSearchResults || _showRecipeDetails)
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                setState(() {
                  _showChat = false;
                  _showSearchResults = false;
                  _showRecipeDetails = false;
                  _showInitialContent = true;
                  _showSuggestions = false;
                  _searchController.clear();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_showRecipeDetails)
            _buildSearchBar(),
          if (_error != null && (_error!.contains('API key') || _error!.contains('model')))
            _buildApiErrorMessage()
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_isLoading && !_showChat)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            if (_showSuggestions && !_showRecipeDetails) 
              _buildSuggestionsList(),
            if (_showSearchResults && !_showSuggestions && !_showChat && !_showRecipeDetails) 
              _buildSearchResults(),
            if (_showInitialContent && !_showSuggestions && !_showSearchResults && !_showChat && !_showRecipeDetails) 
              _buildInitialContent(),
            if (_showChat && !_showRecipeDetails) 
              _buildChatSection(),
            if (_showRecipeDetails)
              Expanded(child: _buildRecipeDetailsScreen()),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search recipes...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_isLoading && !_showChat)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _suggestions = [];
                          _showSuggestions = false;
                          _error = null;
                        });
                      },
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) => _getSuggestions(value),
            onSubmitted: (value) => _searchRecipes(value),
          ),
          if (!_showChat && !_showSuggestions && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _getRecipesFromInventory,
                      icon: const Icon(Icons.kitchen),
                      label: const Text('Based on Your Kitchen'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApiErrorMessage() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'API Key Issue',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              Text(
                'To fix this issue:\n\n1. Get a new API key from: https://aistudio.google.com/app/apikey\n\n2. Update the API key in lib/services/gemini_service.dart',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _testGeminiConnection,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 200, // Set a maximum height for suggestions list
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length > 4 ? 4 : _suggestions.length, // Limit number of suggestions
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true, // Make the list tile more compact
                  visualDensity: VisualDensity.compact, // More compact styling
                  title: Text(
                    _suggestions[index],
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  onTap: () {
                    _searchController.text = _suggestions[index];
                    _searchRecipes(_suggestions[index]);
                  },
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: TextButton(
              onPressed: () => _searchRecipes(_searchController.text),
              child: const Text('Show All Results'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Results for "${_searchController.text}"',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return _buildRecipeCard(
                    result['name'] ?? '',
                    result['description'] ?? '',
                  );
                },
              ),
            ),
          ],
          
          if (_inventoryBasedRecipes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Recipes from Your Kitchen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _inventoryBasedRecipes.length,
                itemBuilder: (context, index) {
                  final result = _inventoryBasedRecipes[index];
                  return _buildRecipeCard(
                    result['name'] ?? '',
                    result['description'] ?? '',
                  );
                },
              ),
            ),
          ],
          
          if (_searchResults.isEmpty && _inventoryBasedRecipes.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recipes found',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try a different search term or ask Yumly Bot',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showChat = true;
                          _showSearchResults = false;
                        });
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Ask Yumly Bot'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildRecipeCard(String title, String description) {
    final Map<String, String> recipeData = _searchResults.firstWhere(
      (r) => r['name'] == title,
      orElse: () => _inventoryBasedRecipes.firstWhere(
        (r) => r['name'] == title,
        orElse: () => {'name': title, 'description': description},
      ),
    );
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('View Recipe'),
                  onPressed: () => _displayRecipeDetails(recipeData, false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialContent() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Find the Perfect Recipe',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for dishes or use ingredients from your kitchen',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Have a specific dish in mind?',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showChat = true;
                        _chatMessages = [
                          {'bot': 'Hi! I\'m Yumly Bot. What recipe would you like to know about today?'}
                        ];
                      });
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Ask Yumly Bot'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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

  Widget _buildChatSection() {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              controller: _scrollController,
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final message = _chatMessages[index];
                final isUser = message.containsKey('user');
                final text = isUser ? message['user']! : message['bot']!;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Thinking...',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Ask about recipes...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      enabled: !_isLoading,
                    ),
                    onSubmitted: _isLoading ? null : (value) => _sendChatMessage(value),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : () => _sendChatMessage(_chatController.text),
                    iconSize: 20,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
