import 'package:flutter/material.dart';

IconData iconForEventType(String eventType) {
  switch (eventType) {
    case 'wedding':
      return Icons.favorite_outline_rounded;
    case 'birthday':
      return Icons.cake_outlined;
    case 'graduation':
      return Icons.school_outlined;
    case 'anniversary':
      return Icons.favorite_border_rounded;
    case 'baby_shower':
      return Icons.child_friendly_outlined;
    case 'corporate':
      return Icons.business_center_outlined;
    case 'party':
      return Icons.celebration_outlined;
    case 'travel':
      return Icons.flight_takeoff_outlined;
    default:
      return Icons.photo_camera_outlined;
  }
}
