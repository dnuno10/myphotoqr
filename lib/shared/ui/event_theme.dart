import 'package:flutter/material.dart';

class EventThemeCopy {
  const EventThemeCopy({
    required this.emoji,
    required this.label,
    required this.guestTitle,
    required this.guestDescription,
    required this.uploadTitle,
    required this.uploadDescription,
  });

  final String emoji;
  final String label;
  final String guestTitle;
  final String guestDescription;
  final String uploadTitle;
  final String uploadDescription;
}

EventThemeCopy eventThemeCopy(String eventType) {
  switch (eventType) {
    case 'wedding':
      return const EventThemeCopy(
        emoji: '💍',
        label: 'Wedding',
        guestTitle: 'Wedding memories',
        guestDescription:
            'Share photos, videos, and messages to save every moment of this celebration.',
        uploadTitle: 'Upload a wedding memory',
        uploadDescription: 'Add photos, videos, or a special note for the couple.',
      );
    case 'birthday':
      return const EventThemeCopy(
        emoji: '🎂',
        label: 'Birthday',
        guestTitle: 'Birthday memories',
        guestDescription: 'Save the moments, laughs, and messages from this birthday.',
        uploadTitle: 'Upload a birthday memory',
        uploadDescription: 'Add photos, videos, or a note for the birthday person.',
      );
    case 'graduation':
      return const EventThemeCopy(
        emoji: '🎓',
        label: 'Graduation',
        guestTitle: 'Graduation memories',
        guestDescription:
            'Collect photos, videos, and messages from this important milestone.',
        uploadTitle: 'Upload a graduation memory',
        uploadDescription: 'Share a moment, a message, or a video from the day.',
      );
    case 'anniversary':
      return const EventThemeCopy(
        emoji: '❤️',
        label: 'Anniversary',
        guestTitle: 'Anniversary memories',
        guestDescription:
            'Celebrate the story with photos, videos, and meaningful messages.',
        uploadTitle: 'Upload an anniversary memory',
        uploadDescription: 'Share a photo, video, or note for this date.',
      );
    case 'baby_shower':
      return const EventThemeCopy(
        emoji: '🍼',
        label: 'Baby shower',
        guestTitle: 'Baby shower memories',
        guestDescription:
            'Save messages, photos, and videos to welcome the baby.',
        uploadTitle: 'Upload a baby shower memory',
        uploadDescription: 'Add photos, videos, or a heartfelt note.',
      );
    case 'corporate':
      return const EventThemeCopy(
        emoji: '🏢',
        label: 'Event',
        guestTitle: 'Event moments',
        guestDescription:
            'Collect photos, videos, and notes from attendees in one place.',
        uploadTitle: 'Upload event content',
        uploadDescription: 'Share photos, videos, or a note from the moment.',
      );
    case 'party':
      return const EventThemeCopy(
        emoji: '🎉',
        label: 'Party',
        guestTitle: 'Party memories',
        guestDescription:
            'Share the best moments, videos, and messages from the party.',
        uploadTitle: 'Upload a party memory',
        uploadDescription: 'Add photos, videos, or a note for the album.',
      );
    case 'travel':
      return const EventThemeCopy(
        emoji: '✈️',
        label: 'Travel',
        guestTitle: 'Travel memories',
        guestDescription:
            'Save landscapes, moments, and notes from this experience.',
        uploadTitle: 'Upload a travel memory',
        uploadDescription: 'Share photos, videos, or a note from the adventure.',
      );
    default:
      return const EventThemeCopy(
        emoji: '📸',
        label: 'Album',
        guestTitle: 'Album memories',
        guestDescription:
            'Share photos, videos, and notes to preserve this moment.',
        uploadTitle: 'Upload your memories',
        uploadDescription: 'Add photos, videos, or a note to the album.',
      );
  }
}

Color eventAccentColor(String eventType) {
  switch (eventType) {
    case 'wedding':
      return const Color(0xFFD9A8B8);
    case 'birthday':
      return const Color(0xFFF2B84B);
    case 'graduation':
      return const Color(0xFF315C86);
    case 'anniversary':
      return const Color(0xFFD14D72);
    case 'baby_shower':
      return const Color(0xFF8EB8D8);
    case 'corporate':
      return const Color(0xFF44546A);
    case 'party':
      return const Color(0xFF8B5CF6);
    case 'travel':
      return const Color(0xFF3B8C73);
    default:
      return const Color(0xFF111111);
  }
}
