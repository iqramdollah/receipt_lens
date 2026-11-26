import 'package:material_ui/material_ui.dart';

/// One icon per default category; anything else gets a generic receipt icon.
IconData categoryIcon(String? name) => switch (name) {
  'Food' => Icons.restaurant_outlined,
  'Groceries' => Icons.shopping_basket_outlined,
  'Transport' => Icons.directions_car_outlined,
  'Shopping' => Icons.shopping_bag_outlined,
  'Bills' => Icons.bolt_outlined,
  'Health' => Icons.favorite_border,
  'Entertainment' => Icons.movie_outlined,
  _ => Icons.receipt_long_outlined,
};
