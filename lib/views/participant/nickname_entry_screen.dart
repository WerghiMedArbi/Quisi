import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_background.dart';
import '../../utils/avatar_provider.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NicknameEntryScreen extends StatefulWidget {
  final String sessionId;
  
  const NicknameEntryScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _NicknameEntryScreenState createState() => _NicknameEntryScreenState();
}

class _NicknameEntryScreenState extends State<NicknameEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int? _selectedAvatarIndex;
  Set<String> _takenAvatarSeeds = {};
  bool _isCheckingNickname = false;
  bool _isNicknameAvailable = true;
  String _nicknameErrorMessage = '';

  // Using the avatar styles from our provider utility
  final List<String> _avatarStyles = AvatarProvider.avatarStyles;

  // Random avatar seeds for variety
  final List<String> _avatarSeeds = List.generate(
    36, 
    (index) => index.toString(),
  );

  // Selected avatar style
  String _selectedStyle = 'avataaars';
  
  // Selected background color
  Color _selectedBgColor = AvatarProvider.bgColorOptions[0]; // Default light blue
  
  // Background color options from our provider utility
  final List<Color> _bgColorOptions = AvatarProvider.bgColorOptions;

  @override
  void initState() {
    super.initState();
    _fetchTakenAvatars();
  }

  // Fetch already taken avatars to prevent duplicates
  Future<void> _fetchTakenAvatars() async {
    try {
      final participantsSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .get();
      
      setState(() {
        _takenAvatarSeeds = participantsSnapshot.docs
            .map((doc) {
              final avatarSeed = doc.data()['avatarSeed'] as String?;
              final avatarStyle = doc.data()['avatarStyle'] as String?;
              
              if (avatarSeed != null && avatarStyle != null) {
                return '$avatarStyle:$avatarSeed';
              }
              return null;
            })
            .where((seed) => seed != null)
            .cast<String>()
            .toSet();
      });
    } catch (e) {
      print('Error fetching taken avatars: $e');
    }
  }

  // Check if nickname is already taken
  Future<void> _checkNicknameAvailability(String nickname) async {
    if (nickname.isEmpty) return;
    
    setState(() {
      _isCheckingNickname = true;
      _isNicknameAvailable = true;
      _nicknameErrorMessage = '';
    });
    
    try {
      final participants = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .where('name', isEqualTo: nickname)
          .get();
      
      setState(() {
        _isCheckingNickname = false;
        _isNicknameAvailable = participants.docs.isEmpty;
        if (!_isNicknameAvailable) {
          _nicknameErrorMessage = 'This nickname is already taken';
        }
      });
    } catch (e) {
      setState(() {
        _isCheckingNickname = false;
        _nicknameErrorMessage = 'Error checking nickname';
      });
      print('Error checking nickname: $e');
    }
  }

  // Get the DiceBear avatar URL using the avatar provider
  String _getAvatarUrl(String style, String seed) {
    return AvatarProvider.getAvatarUrl(style, seed, _selectedBgColor);
  }
  
  // Check if a specific avatar is taken
  bool _isAvatarTaken(String style, String seed) {
    return _takenAvatarSeeds.contains('$style:$seed');
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 400; // Threshold for small screens
    
    return Scaffold(
      appBar: AppBackground.buildAppBar(title: 'Join Quiz'),
      body: AppBackground.buildBackground(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Text(
                  'Choose your nickname and avatar', 
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 20 : 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Both your nickname and avatar must be unique',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 20, 
                        vertical: isSmallScreen ? 20 : 24
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nickname field
                          Text(
                            'Your Nickname',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
              TextFormField(
                controller: _nicknameController,
                            style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                            decoration: InputDecoration(
                              hintText: 'Enter your nickname',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                              ),
                              prefixIcon: Icon(Icons.person, color: Colors.blue.shade700),
                              suffixIcon: _isCheckingNickname
                                  ? Container(
                                      width: 20,
                                      height: 20,
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : _nicknameController.text.isNotEmpty
                                      ? Icon(
                                          _isNicknameAvailable
                                              ? Icons.check_circle
                                              : Icons.error,
                                          color: _isNicknameAvailable
                                              ? Colors.green
                                              : Colors.red,
                                        )
                                      : null,
                              errorText: _nicknameErrorMessage.isNotEmpty
                                  ? _nicknameErrorMessage
                                  : null,
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a nickname';
                  }
                              if (!_isNicknameAvailable) {
                                return 'This nickname is already taken';
                  }
                  return null;
                },
                            onChanged: (value) {
                              _checkNicknameAvailability(value);
                            },
                          ),
                          SizedBox(height: 24),
                          
                          // Background color chooser
                          Text(
                            'Avatar Background Color',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.all(8),
                              scrollDirection: Axis.horizontal,
                              itemCount: _bgColorOptions.length,
                              itemBuilder: (context, index) {
                                final color = _bgColorOptions[index];
                                final isSelected = _selectedBgColor == color;
                                
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedBgColor = color;
                                    });
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    margin: EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue.shade700
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: isSelected 
                                      ? Icon(Icons.check, color: Colors.black54)
                                      : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 24),
                          
                          // Avatar style selector
                          Text(
                            'Avatar Style',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            height: 100,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.all(8),
                              scrollDirection: Axis.horizontal,
                              itemCount: _avatarStyles.length,
                              itemBuilder: (context, index) {
                                final style = _avatarStyles[index];
                                final isSelected = _selectedStyle == style;
                                final avatarUrl = _getAvatarUrl(style, 'example');
                                
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedStyle = style;
                                      // Reset avatar selection when changing style
                                      _selectedAvatarIndex = null;
                                    });
                                  },
                                  child: Container(
                                    width: 80,
                                    margin: EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? Colors.blue.shade50
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue.shade700
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: AvatarProvider.buildCachedAvatar(
                                            imageUrl: avatarUrl,
                                            width: 50,
                                            height: 50,
                                            seed: 'example',
                                            style: style,
                                            backgroundColor: _selectedBgColor,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          style.charAt(0).toUpperCase() + style.substring(1),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 24),
                          
                          // Avatar selection grid
                          Text(
                            'Choose Your Avatar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          SizedBox(height: 12),
                          
                          // Grid of avatar options
                          Container(
                            height: screenHeight * 0.3, // Responsive height
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: GridView.builder(
                              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isSmallScreen ? 2 : 3,
                                mainAxisSpacing: isSmallScreen ? 8 : 12,
                                crossAxisSpacing: isSmallScreen ? 8 : 12,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: _avatarSeeds.length,
                              itemBuilder: (context, index) {
                                final seed = _avatarSeeds[index];
                                final bool isSelected = _selectedAvatarIndex == index;
                                final bool isTaken = _isAvatarTaken(_selectedStyle, seed);
                                final String avatarUrl = _getAvatarUrl(_selectedStyle, seed);
                                
                                return GestureDetector(
                                  onTap: isTaken ? null : () {
                                    setState(() {
                                      _selectedAvatarIndex = index;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isTaken
                                          ? Colors.grey.shade200
                                          : isSelected
                                              ? Colors.blue.shade50
                                              : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isTaken
                                            ? Colors.grey.shade400
                                            : isSelected
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        isSelected
                                            ? AvatarGlow(
                                                glowColor: Colors.blue,
                                                child: _buildAvatarImage(avatarUrl, isTaken, seed),
                                                duration: Duration(milliseconds: 2000),
                                                repeat: true,
                                              )
                                            : _buildAvatarImage(avatarUrl, isTaken, seed),
                                        if (isTaken)
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text(
                                              'Taken',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          // Selected avatar display
                          if (_selectedAvatarIndex != null) ...[
                            SizedBox(height: 24),
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AvatarProvider.buildCachedAvatar(
                                    imageUrl: _getAvatarUrl(_selectedStyle, _avatarSeeds[_selectedAvatarIndex!]),
                                    width: 60,
                                    height: 60,
                                    seed: _avatarSeeds[_selectedAvatarIndex!],
                                    style: _selectedStyle,
                                    backgroundColor: _selectedBgColor,
                                    fallbackText: _nicknameController.text.isNotEmpty 
                                        ? AvatarProvider.getFirstLetter(_nicknameController.text)
                                        : "?",
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your selected avatar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Style: ${_selectedStyle.charAt(0).toUpperCase() + _selectedStyle.substring(1)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          // Error message display
              if (_errorMessage != null)
                Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red),
                                    SizedBox(width: 10),
                                    Expanded(
                  child: Text(
                    _errorMessage!,
                                        style: TextStyle(color: Colors.red.shade800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          SizedBox(height: 24),
                          
                          // Join button
              _isLoading 
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              )
                : ElevatedButton(
                    onPressed: _joinSession,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'JOIN QUIZ',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build avatar image with advanced fallback
  Widget _buildAvatarImage(String imageUrl, bool isTaken, String seed) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          isTaken ? Colors.grey : Colors.transparent,
          isTaken ? BlendMode.saturation : BlendMode.srcOver,
        ),
        child: AvatarProvider.buildCachedAvatar(
          imageUrl: imageUrl,
          width: 60,
          height: 60,
          seed: seed,
          style: _selectedStyle,
          backgroundColor: _selectedBgColor,
          fallbackText: _nicknameController.text.isNotEmpty 
              ? AvatarProvider.getFirstLetter(_nicknameController.text)
              : seed[0],
        ),
      ),
    );
  }

  Future<void> _joinSession() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate avatar selection
    if (_selectedAvatarIndex == null) {
      setState(() {
        _errorMessage = 'Please select an avatar';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // First verify the session exists
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .get();
          
      if (!sessionDoc.exists) {
        setState(() {
          _errorMessage = 'Session not found';
          _isLoading = false;
        });
        return;
      }
      
      // Double check for nickname uniqueness
      final nicknameCheck = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .where('name', isEqualTo: _nicknameController.text)
          .get();
          
      if (nicknameCheck.docs.isNotEmpty) {
        setState(() {
          _errorMessage = 'This nickname is already taken. Please choose another one.';
          _isNicknameAvailable = false;
          _nicknameErrorMessage = 'Nickname already taken';
          _isLoading = false;
        });
        return;
      }
      
      // Double check for avatar uniqueness
      final selectedSeed = _avatarSeeds[_selectedAvatarIndex!];
      final avatarKey = '$_selectedStyle:$selectedSeed';
      final avatarCheck = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .where('avatarKey', isEqualTo: avatarKey)
          .get();
          
      if (avatarCheck.docs.isNotEmpty) {
        setState(() {
          _errorMessage = 'This avatar is already taken. Please choose another one.';
          _takenAvatarSeeds.add(avatarKey);
          _selectedAvatarIndex = null;
          _isLoading = false;
        });
        return;
      }
      
      // Get the quizId from the session
      final quizId = sessionDoc.data()?['quizId'] ?? 'quizId1';
      
      // Generate a unique participant ID
      final participantRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .doc();
          
      // Convert color to hex for saving to database
      String bgColorHex = _selectedBgColor.value.toRadixString(16).substring(2);
      
      // Add the participant to the session with avatar information
      await participantRef.set({
        'name': _nicknameController.text,
        'avatarSeed': selectedSeed,
        'avatarStyle': _selectedStyle,
        'avatarKey': avatarKey,
        'avatarUrl': _getAvatarUrl(_selectedStyle, selectedSeed),
        'avatarBgColor': bgColorHex,
        'score': 0,
        'ready': false,
        'answeredQuestions': [],
        'readyForNextQuestion': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      
      // Navigate to quiz participation screen
      if (!mounted) return;
      context.go('/quiz-participation', extra: {
        'sessionId': widget.sessionId,
        'quizId': quizId,
        'participantId': participantRef.id,
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error joining session: $e';
        _isLoading = false;
      });
      print('Error joining session: $e');
    }
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String charAt(int index) {
    if (index >= 0 && index < this.length) {
      return this[index];
    }
    return '';
  }
}