import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = '';
      // Clear form fields when switching modes
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  bool _validateForm() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return false;

    if (!_isLogin) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return false;
      }
    }
    return true;
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_isLogin) {
        // Login
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        if (mounted) {
          try {
            // Check if user has a name in Firestore
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user?.uid)
                .get();

            if (!userDoc.exists) {
              Navigator.of(context).pushReplacementNamed('/username');
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          } catch (firestoreError) {
            print('Firestore Error: $firestoreError');
            // If Firestore is not accessible, default to username screen
            Navigator.of(context).pushReplacementNamed('/username');
          }
        }
      } else {
        // Sign up
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/username');
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      print('General Error: $e');
      setState(() {
        _errorMessage = 'An error occurred. Please try again later.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('Starting Google Sign In process');
      // Begin interactive sign in process
      final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
      
      if (gUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google sign in was cancelled';
        });
        return;
      }

      print('Google Sign In successful: ${gUser.email}');

      // Obtain auth details from request
      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // Create a new credential for user
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      // Finally, sign in with Firebase
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      print('Firebase Sign In successful. User ID: ${userCredential.user?.uid}');
      
      if (mounted) {
        try {
          // Check if user has a name in Firestore
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user?.uid)
              .get();

          if (!userDoc.exists) {
            Navigator.of(context).pushReplacementNamed('/username');
          } else {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        } catch (firestoreError) {
          print('Firestore Error: $firestoreError');
          // If Firestore is not accessible, default to username screen
          Navigator.of(context).pushReplacementNamed('/username');
        }
      }
      
    } catch (e) {
      print('Google Sign In Error: $e');
      setState(() {
        _errorMessage = 'Failed to sign in with Google. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (!_isLogin && value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Confirm Password Field (Sign Up only)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Error Message
                if (_errorMessage.isNotEmpty) ...[
                  Text(
                    _errorMessage,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_isLogin ? 'Login' : 'Sign Up'),
                ),
                const SizedBox(height: 16),
                
                // Switch Mode Button
                TextButton(
                  onPressed: _isLoading ? null : _switchAuthMode,
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Sign Up"
                        : 'Already have an account? Login',
                  ),
                ),

                // Google Sign In Section (Login mode only)
                if (_isLogin) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.onBackground.withOpacity(0.3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: theme.colorScheme.onBackground.withOpacity(0.6),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.onBackground.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/google_logo.png'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Sign in with Google'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 