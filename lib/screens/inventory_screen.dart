import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class FilterOption {
  final String label;
  final String value;
  final IconData icon;

  const FilterOption({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedFilter = 'All';
  bool _isFilterMenuOpen = false;
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;
  
  final List<FilterOption> _categories = const [
    FilterOption(label: 'All Categories', value: 'All', icon: Icons.category),
    FilterOption(label: 'Vegetables', value: 'Vegetables', icon: Icons.eco),
    FilterOption(label: 'Fruits', value: 'Fruits', icon: Icons.apple),
    FilterOption(label: 'Dairy', value: 'Dairy', icon: Icons.egg),
    FilterOption(label: 'Meat', value: 'Meat', icon: Icons.restaurant_menu),
    FilterOption(label: 'Grains', value: 'Grains', icon: Icons.grain),
    FilterOption(label: 'Spices', value: 'Spices', icon: Icons.spa),
    FilterOption(label: 'Other', value: 'Other', icon: Icons.more_horiz),
  ];
  
  final List<FilterOption> _filterOptions = const [
    FilterOption(label: 'All Items', value: 'All', icon: Icons.all_inbox),
    FilterOption(label: 'Expiring Soon', value: 'Expiring Soon', icon: Icons.timer),
    FilterOption(label: 'Expired', value: 'Expired', icon: Icons.warning),
    FilterOption(label: 'Not Expired', value: 'Valid', icon: Icons.check_circle),
  ];
  
  final List<String> _units = ['kg', 'g', 'L', 'ml', 'pieces', 'packets'];

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  List<InventoryItem> _filterItems(List<InventoryItem> items) {
    return items.where((item) {
      // Apply search filter
      final searchMatch = _searchController.text.isEmpty ||
          item.name.toLowerCase().contains(_searchController.text.toLowerCase());

      // Apply category filter
      final categoryMatch = _selectedCategory == 'All' ||
          item.category == _selectedCategory;

      // Apply status filter
      bool statusMatch = true;
      switch (_selectedFilter) {
        case 'Expiring Soon':
          statusMatch = item.isExpiringSoon;
          break;
        case 'Expired':
          statusMatch = item.isExpired;
          break;
        case 'Valid':
          statusMatch = !item.isExpired && !item.isExpiringSoon;
          break;
        default:
          statusMatch = true;
      }

      return searchMatch && categoryMatch && statusMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        elevation: 2,
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: _inventoryService.getInventoryItems(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final items = snapshot.data ?? [];
                final filteredItems = _filterItems(items);
                
                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          items.isEmpty ? 'No items in inventory' : 'No matching items found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          items.isEmpty ? 'Tap + to add items' : 'Try adjusting your filters',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                // Separate expired and non-expired items
                final expiredItems = filteredItems.where((item) => item.isExpired).toList();
                final validItems = filteredItems.where((item) => !item.isExpired).toList();

                return CustomScrollView(
                  slivers: [
                    if (expiredItems.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Expired Items',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: const Color(0xFFFF6F61),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildInventoryItemCard(expiredItems[index]),
                          childCount: expiredItems.length,
                        ),
                      ),
                    ],
                    if (validItems.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Items',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildInventoryItemCard(validItems[index]),
                          childCount: validItems.length,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditItemDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search ingredients...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterButton(
                'Category',
                _selectedCategory,
                _categories,
                Icons.category,
              ),
              const SizedBox(width: 8),
              _buildFilterButton(
                'Status',
                _selectedFilter,
                _filterOptions,
                Icons.filter_list,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    String title,
    String selectedValue,
    List<FilterOption> options,
    IconData icon,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          _showFilterBottomSheet(title, selectedValue, options);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet(
    String title,
    String selectedValue,
    List<FilterOption> options,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        tween: Tween(begin: 1, end: 0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, value * 200),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option.value == selectedValue;
                    return ListTile(
                      leading: Icon(
                        option.icon,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(option.label),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          if (title == 'Category') {
                            _selectedCategory = option.value;
                          } else {
                            _selectedFilter = option.value;
                          }
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryItemCard(InventoryItem item) {
    final theme = Theme.of(context);
    final isExpired = item.isExpired;
    final isExpiringSoon = item.isExpiringSoon;

    Color cardColor = theme.cardColor;
    if (isExpired) {
      cardColor = const Color(0xFFFF6F61).withOpacity(0.1);
    } else if (isExpiringSoon) {
      cardColor = const Color(0xFFD6A84E).withOpacity(0.1);
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          item.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            decoration: isExpired ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Quantity: ${item.quantity} ${item.unit}',
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Category: ${item.category}',
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Expires: ${DateFormat('MMM dd, yyyy').format(item.expiryDate)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isExpired
                          ? const Color(0xFFFF6F61)
                          : isExpiringSoon
                              ? const Color(0xFFD6A84E)
                              : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isExpired)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.warning, color: Color(0xFFFF6F61), size: 16),
                  )
                else if (isExpiringSoon)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.access_time, color: Color(0xFFD6A84E), size: 16),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showAddEditItemDialog(context, item: item);
            } else if (value == 'delete') {
              _showDeleteConfirmationDialog(item);
            } else if (value == 'recipe') {
              Navigator.pushNamed(context, '/recipes', arguments: item);
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'recipe',
              child: Row(
                children: [
                  Icon(Icons.restaurant),
                  SizedBox(width: 8),
                  Text('Find Recipes'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddEditItemDialog(BuildContext context,
      {InventoryItem? item}) async {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final quantityController =
        TextEditingController(text: item?.quantity.toString() ?? '');
    String selectedCategory = item?.category ?? _categories.first.value;
    String selectedUnit = item?.unit ?? _units.first;
    DateTime selectedDate = item?.expiryDate ?? DateTime.now();

    await showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              title: Text(isEditing ? 'Edit Item' : 'Add New Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: selectedUnit,
                          items: _units.map((String unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedUnit = newValue;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: _categories.map((FilterOption option) {
                        return DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedCategory = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Expiry Date'),
                      subtitle: Text(
                        DateFormat('MMM dd, yyyy').format(selectedDate),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        quantityController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all fields'),
                        ),
                      );
                      return;
                    }

                    final quantity = double.tryParse(quantityController.text);
                    if (quantity == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid quantity'),
                        ),
                      );
                      return;
                    }

                    final userId = FirebaseAuth.instance.currentUser?.uid;
                    if (userId == null) return;

                    final newItem = InventoryItem(
                      id: item?.id ?? '',
                      name: nameController.text.trim(),
                      quantity: quantity,
                      expiryDate: selectedDate,
                      category: selectedCategory,
                      unit: selectedUnit,
                      userId: userId,
                    );

                    try {
                      if (isEditing) {
                        await _inventoryService.updateItem(newItem);
                      } else {
                        await _inventoryService.addItem(newItem);
                      }
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(isEditing ? 'Update' : 'Add'),
                ),
              ],
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _showDeleteConfirmationDialog(InventoryItem item) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Are you sure you want to delete ${item.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _inventoryService.deleteItem(item.id);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting item: $e'),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F61),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
