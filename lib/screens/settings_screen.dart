import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yumly/main.dart'; // Import to access themeNotifier

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isDarkMode = false;
  bool _isLoading = false;
  String _userName = '';
  String _userEmail = '';
  String _appVersion = '1.0.0';
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppInfo();
    _loadThemePreference();
    
    // Setup animation controller for theme transition
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController, 
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        setState(() {
          _userEmail = user.email ?? 'No email';
        });
        
        // Get user name from Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          setState(() {
            _userName = userDoc.data()?['name'] ?? 'User';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      print('Error loading app info: $e');
    }
  }
  
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
    } catch (e) {
      print('Error loading theme preference: $e');
    }
  }
  
  Future<void> _toggleTheme(bool value) async {
    // Start animation
    if (value) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    
    setState(() {
      _isDarkMode = value;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', value);
      
      // Update the global theme notifier
      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }
  
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
  
  Future<void> _deleteAccount() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6F61), // Mild Coral
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        final batch = _firestore.batch();
        
        // Delete user document
        final userDoc = _firestore.collection('users').doc(user.uid);
        batch.delete(userDoc);
        
        // Delete user's inventory
        final inventorySnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('inventory')
            .get();
            
        for (var doc in inventorySnapshot.docs) {
          batch.delete(doc.reference);
        }
        
        // Delete user's meal plans
        final mealPlansSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('mealPlans')
            .get();
            
        for (var doc in mealPlansSnapshot.docs) {
          batch.delete(doc.reference);
        }
        
        // Commit batch deletion
        await batch.commit();
        
        // Delete user authentication
        await user.delete();
        
        // Navigate to auth screen
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      print('Error deleting account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _changePassword() async {
    if (_auth.currentUser?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email associated with this account')),
      );
      return;
    }
    
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    
    final formKey = GlobalKey<FormState>();
    
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
    
    if (result != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Re-authenticate user
      final user = _auth.currentUser;
      final credential = EmailAuthProvider.credential(
        email: user?.email ?? '',
        password: currentPasswordController.text,
      );
      
      await user?.reauthenticateWithCredential(credential);
      
      // Change password
      await user?.updatePassword(newPasswordController.text);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      
      if (e.code == 'wrong-password') {
        errorMessage = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The new password is too weak';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Please sign out and sign in again before changing your password';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      print('Error changing password: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error changing password: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 2,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userEmail,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        ListTile(
                          leading: Icon(Icons.password, color: theme.iconTheme.color),
                          title: Text('Change Password', style: TextStyle(color: theme.colorScheme.onSurface)),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.iconTheme.color),
                          contentPadding: EdgeInsets.zero,
                          onTap: _changePassword,
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Color(0xFFFF6F61)),
                          title: const Text(
                            'Sign Out',
                            style: TextStyle(color: Color(0xFFFF6F61)),
                          ),
                          contentPadding: EdgeInsets.zero,
                          onTap: _signOut,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Theme Section
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: Text('Dark Mode', style: TextStyle(color: theme.colorScheme.onSurface)),
                          subtitle: Text(
                            _isDarkMode 
                              ? 'Using dark color scheme' 
                              : 'Using light color scheme',
                            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                          ),
                          secondary: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                              key: ValueKey<bool>(_isDarkMode),
                              color: _isDarkMode 
                                ? Color.lerp(theme.colorScheme.secondary, theme.colorScheme.primary, _animation.value)
                                : theme.colorScheme.primary,
                            ),
                          ),
                          value: _isDarkMode,
                          onChanged: _toggleTheme,
                          contentPadding: EdgeInsets.zero,
                          activeColor: theme.colorScheme.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Navigation Section
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Icon(Icons.inventory_2, color: theme.iconTheme.color),
                          title: Text('Manage Inventory', style: TextStyle(color: theme.colorScheme.onSurface)),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.iconTheme.color),
                          contentPadding: EdgeInsets.zero,
                          onTap: () => Navigator.pushNamed(context, '/inventory'),
                        ),
                        ListTile(
                          leading: Icon(Icons.calendar_today, color: theme.iconTheme.color),
                          title: Text('Manage Meal Plans', style: TextStyle(color: theme.colorScheme.onSurface)),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.iconTheme.color),
                          contentPadding: EdgeInsets.zero,
                          onTap: () => Navigator.pushNamed(context, '/mealplan'),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // About Section
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: Text('App Version', style: TextStyle(color: theme.colorScheme.onSurface)),
                          subtitle: Text('v$_appVersion', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                          leading: Icon(Icons.info, color: theme.iconTheme.color),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(),
                        ListTile(
                          title: Text('Developer Info', style: TextStyle(color: theme.colorScheme.onSurface)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• Vinamra Srivastava: Backend & AI Integration', 
                                   style: TextStyle(color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 8),
                              Text('• Adhyayan Dubey: Front End', 
                                   style: TextStyle(color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 8),
                              Text('• Aditi Prasanth: UI/UX Design', 
                                   style: TextStyle(color: theme.colorScheme.onSurface)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        ListTile(
                          title: Text('About Yumly', style: TextStyle(color: theme.colorScheme.onSurface)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Yumly is your intelligent kitchen companion that makes cooking a delightful experience. '
                            'Manage your food inventory, discover personalized recipes based on ingredients you have, '
                            'plan your meals for the week, and generate smart shopping lists—all in one place. '
                            'With AI-powered suggestions and a user-friendly interface, Yumly transforms how you cook and plan meals.',
                            style: TextStyle(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Delete Account Section
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.delete_forever, color: Color(0xFFFF6F61)),
                          title: const Text(
                            'Delete Account',
                            style: TextStyle(color: Color(0xFFFF6F61)),
                          ),
                          subtitle: const Text(
                            'This action cannot be undone.',
                            style: TextStyle(color: Color(0xFFFF6F61)),
                          ),
                          contentPadding: EdgeInsets.zero,
                          onTap: _deleteAccount,
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
