class AppConstants {
  AppConstants._();

  static const String appName = 'Finders Keepers';
  static const String appTagline = 'Campus Lost & Found, Simplified';

  // VIT Email validation regex: only allow vitstudent.ac.in or vit.ac.in
  static final RegExp vitEmailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@(?:[a-zA-Z0-9-]+\.)?(?:vitstudent\.ac\.in|vit\.ac\.in)$',
    caseSensitive: false,
  );

  static bool isValidVitEmail(String email) {
    return vitEmailRegex.hasMatch(email.trim());
  }

  // Campus Default Coordinates (VIT Vellore)
  static const double defaultLatitude = 12.9698;
  static const double defaultLongitude = 79.1559;
  static const String defaultCampusLabel = 'VIT Campus';

  // Categories
  static const List<String> categories = [
    'All',
    'Electronics',
    'ID Cards',
    'Books & Notes',
    'Keys',
    'Clothing',
    'Bags & Wallets',
    'Bottles',
    'Watches & Jewelry',
    'Others',
  ];

  // Firestore Collections
  static const String itemsCollection = 'items';
  static const String claimsCollection = 'claims';
  static const String usersCollection = 'users';
}
