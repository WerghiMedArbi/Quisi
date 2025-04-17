import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Global navigator key for router
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// A utility class that provides consistent background styling across the app
class AppBackground {
  /// Button color constants
  static final Color primaryButtonColor = Colors.white;
  static final Color primaryButtonTextColor = Colors.blue.shade700;
  static final Color secondaryButtonColor = Colors.blue.shade700;
  static final Color secondaryButtonTextColor = Colors.white;
  static final Color dangerButtonColor = Colors.red.shade600;
  static final Color successButtonColor = Colors.green.shade600;

  static Color backgroundColor = const Color(0xFFF5F8FF);
  static Color primaryColor = const Color(0xFF5855D6);
  static Color textColor = Colors.black;

  /// Creates a Container with the standard blue background with bg.png overlay
  static Widget buildBackground({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        image: DecorationImage(
          image: AssetImage('assets/images/bg.png'),
          fit: BoxFit.cover,
          opacity: 0.0,
        ),
      ),
      child: child,
    );
  }

  /// Provides the standard app background as a BoxDecoration
  static BoxDecoration get backgroundDecoration => BoxDecoration(
    color: backgroundColor,
    image: DecorationImage(
      image: AssetImage('assets/images/bg.png'),
      fit: BoxFit.cover,
      opacity: 0.1,
    ),
  );

  /// Standard app bar settings for consistency
  static PreferredSizeWidget buildAppBar({
    required String title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // QUISI Logo
          Row(
            children: [
              Text(
                "QU",
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                "ISI",
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          if (actions != null) Row(children: actions),
        ],
      ),
      leading: leading ?? (navigatorKey.currentState?.canPop() ?? false
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => navigatorKey.currentState?.pop(),
            )
          : null),
    );
  }

  /// Standard button style for primary actions
  static ButtonStyle primaryButtonStyle({double? width}) {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      minimumSize: Size(width ?? double.infinity, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
    );
  }

  /// Standard button style for secondary actions
  static ButtonStyle secondaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: primaryColor,
      minimumSize: Size(double.infinity, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor),
      ),
      elevation: 0,
    );
  }

  /// Standard button style for success actions
  static ButtonStyle successButtonStyle({double? width, double height = 50}) {
    return ElevatedButton.styleFrom(
      backgroundColor: successButtonColor,
      foregroundColor: Colors.white,
      minimumSize: Size(width ?? double.infinity, height),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  /// Standard button style for dangerous actions
  static ButtonStyle dangerButtonStyle({double? width, double height = 50}) {
    return ElevatedButton.styleFrom(
      backgroundColor: dangerButtonColor,
      foregroundColor: Colors.white,
      minimumSize: Size(width ?? double.infinity, height),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  static InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  static TextStyle headingStyle() {
    return GoogleFonts.montserrat(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: textColor,
    );
  }

  static TextStyle subheadingStyle() {
    return GoogleFonts.roboto(
      fontSize: 16,
      color: Colors.grey[700],
    );
  }

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
} 