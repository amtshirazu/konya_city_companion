import 'package:flutter/material.dart';

class PlaceCategory {
  final String id;
  final String label;
  final IconData icon;

  const PlaceCategory({
    required this.id,
    required this.label,
    required this.icon,
  });
}

abstract class PlaceCategories {
  static const historyCulture = PlaceCategory(
    id: 'history-culture',
    label: 'History & Culture',
    icon: Icons.account_balance_outlined,
  );
  static const mosques = PlaceCategory(
    id: 'mosques',
    label: 'Mosques',
    icon: Icons.mosque_outlined,
  );
  static const parksOutdoors = PlaceCategory(
    id: 'parks-outdoors',
    label: 'Parks & Outdoors',
    icon: Icons.park_outlined,
  );
  static const nature = PlaceCategory(
    id: 'nature',
    label: 'Nature',
    icon: Icons.local_florist_outlined,
  );
  static const foodCafes = PlaceCategory(
    id: 'food-cafes',
    label: 'Food & Cafes',
    icon: Icons.restaurant_outlined,
  );
  static const essentials = PlaceCategory(
    id: 'essentials',
    label: 'Essentials',
    icon: Icons.local_hospital_outlined,
  );
  static const transport = PlaceCategory(
    id: 'transport',
    label: 'Transport',
    icon: Icons.directions_bus_outlined,
  );

  static const List<PlaceCategory> all = [
    historyCulture,
    mosques,
    parksOutdoors,
    nature,
    foodCafes,
    essentials,
    transport,
  ];

  static bool isValidCategoryId(String categoryId) {
    if (categoryId == 'all') return true;
    return all.any((cat) => cat.id == categoryId);
  }

  static String getLabel(String categoryId) {
    for (final cat in all) {
      if (cat.id == categoryId) return cat.label;
    }
    return categoryId;
  }
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.address,
    this.latitude,
    this.longitude,
    this.openingHours,
    this.phoneNumber,
    this.websiteUrl,
    this.imageUrl,
    this.priceInfo,
    this.isVerified = false,
    this.lastVerifiedDate,
    this.sourceUrl,
    this.googlePlaceId,
  });

  final String id;
  final String name;
  final String
  category; // Category ID (e.g. 'history-culture', 'mosques', etc.)
  final String description;
  final IconData icon;
  final Color accentColor;

  // Optional contact & location details
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? openingHours;
  final String? phoneNumber;
  final String? websiteUrl;
  final String? imageUrl;
  final String? priceInfo;

  // Verification details
  final bool isVerified;
  final DateTime? lastVerifiedDate;
  final String? sourceUrl;
  final String? googlePlaceId;

  String get categoryLabel => PlaceCategories.getLabel(category);
}
