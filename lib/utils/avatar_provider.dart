import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:math' as math;

/// Avatar Provider utility that handles avatar generation and fallback options
class AvatarProvider {
  // Cache manager for avatars
  static final cacheManager = CacheManager(
    Config(
      'avatarCacheKey',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
    ),
  );

  // Standard background colors for avatars
  static final List<Color> bgColorOptions = [
    Color(0xFFB6E3F4), // Light blue (default)
    Color(0xFFFFD6E0), // Light pink
    Color(0xFFD4F0C8), // Light green
    Color(0xFFFFF0C8), // Light yellow
    Color(0xFFE0D6FF), // Light purple
    Color(0xFFFFE0C8), // Light orange
    Color(0xFFC8F0F0), // Light cyan
    Color(0xFFE0E0E0), // Light gray
  ];

  // Avatar styles available on DiceBear
  static final List<String> avatarStyles = [
    'avataaars',
    'bottts',
    'thumbs',
    'lorelei',
    'micah',
    'adventurer',
    'big-ears',
    'croodles',
    'open-peeps',
    'pixel-art',
    'identicon',
    'initials'
  ];

  // Get a random background color
  static Color getRandomBackgroundColor() {
    return bgColorOptions[math.Random().nextInt(bgColorOptions.length)];
  }

  // Get the DiceBear avatar URL with selected background color
  static String getAvatarUrl(String style, String seed, Color backgroundColor) {
    String bgColorHex = backgroundColor.value.toRadixString(16).substring(2);
    return 'https://api.dicebear.com/6.x/$style/png?seed=$seed&backgroundColor=$bgColorHex';
  }

  // Build a cached avatar widget with error handling and fallbacks
  static Widget buildCachedAvatar({
    required String imageUrl,
    required double width,
    required double height,
    required String seed,
    required String style,
    required Color backgroundColor,
    String fallbackText = "?",
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheManager: cacheManager,
      placeholder: (context, url) => Container(
        color: backgroundColor.withOpacity(0.3),
        child: Center(
          child: SizedBox(
            width: width * 0.5,
            height: height * 0.5,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        // On error, try to use a different style or fallback to an initial
        return _buildFallbackAvatar(
          seed: seed,
          style: style,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
          fallbackText: fallbackText,
        );
      },
    );
  }

  // Build a fallback avatar when the network image fails
  static Widget _buildFallbackAvatar({
    required String seed,
    required String style,
    required double width, 
    required double height,
    required Color backgroundColor,
    required String fallbackText,
  }) {
    // Try to use a more reliable style (identicon or initials)
    if (style != 'identicon' && style != 'initials') {
      // First try identicon which is more reliable
      return CachedNetworkImage(
        imageUrl: getAvatarUrl('identicon', seed, backgroundColor),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheManager: cacheManager,
        placeholder: (context, url) => _buildLoadingAvatar(width, height, backgroundColor),
        errorWidget: (context, url, error) {
          // If identicon fails, try initials
          return CachedNetworkImage(
            imageUrl: getAvatarUrl('initials', seed, backgroundColor),
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheManager: cacheManager,
            placeholder: (context, url) => _buildLoadingAvatar(width, height, backgroundColor),
            errorWidget: (context, url, error) {
              // If all fails, use a local fallback
              return _buildLocalFallbackAvatar(width, height, backgroundColor, fallbackText);
            },
          );
        },
      );
    } else if (style == 'identicon') {
      // If already using identicon, try initials
      return CachedNetworkImage(
        imageUrl: getAvatarUrl('initials', seed, backgroundColor),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheManager: cacheManager,
        placeholder: (context, url) => _buildLoadingAvatar(width, height, backgroundColor),
        errorWidget: (context, url, error) {
          // If initials fails, use a local fallback
          return _buildLocalFallbackAvatar(width, height, backgroundColor, fallbackText);
        },
      );
    } else {
      // Already tried initials, use local fallback
      return _buildLocalFallbackAvatar(width, height, backgroundColor, fallbackText);
    }
  }

  // Build a loading placeholder
  static Widget _buildLoadingAvatar(double width, double height, Color backgroundColor) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor.withOpacity(0.3),
      child: Center(
        child: SizedBox(
          width: width * 0.5,
          height: height * 0.5,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
          ),
        ),
      ),
    );
  }

  // Build a completely local fallback avatar when all remote options fail
  static Widget _buildLocalFallbackAvatar(
    double width, double height, Color backgroundColor, String text) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.3),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(width * 0.15),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: width * 0.5,
          ),
        ),
      ),
    );
  }

  // Get first letter from a string (for initials)
  static String getFirstLetter(String text) {
    if (text.isNotEmpty) {
      return text.substring(0, 1).toUpperCase();
    }
    return "?";
  }
} 