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
        label: 'Boda',
        guestTitle: 'Recuerdos de boda',
        guestDescription:
            'Comparte fotos, videos y mensajes para guardar cada momento de esta celebración.',
        uploadTitle: 'Sube un recuerdo de la boda',
        uploadDescription:
            'Elige fotos, videos o una nota especial para los novios.',
      );
    case 'birthday':
      return const EventThemeCopy(
        emoji: '🎂',
        label: 'Cumpleaños',
        guestTitle: 'Recuerdos de cumpleaños',
        guestDescription:
            'Guarda los momentos, risas y mensajes de este cumpleaños.',
        uploadTitle: 'Sube un recuerdo del cumpleaños',
        uploadDescription:
            'Agrega fotos, videos o una nota para quien cumple años.',
      );
    case 'graduation':
      return const EventThemeCopy(
        emoji: '🎓',
        label: 'Graduación',
        guestTitle: 'Recuerdos de graduación',
        guestDescription:
            'Reúne fotos, videos y mensajes de este logro importante.',
        uploadTitle: 'Sube un recuerdo de la graduación',
        uploadDescription: 'Comparte un momento, felicitación o video del día.',
      );
    case 'anniversary':
      return const EventThemeCopy(
        emoji: '❤️',
        label: 'Aniversario',
        guestTitle: 'Recuerdos de aniversario',
        guestDescription:
            'Celebra la historia con fotos, videos y mensajes memorables.',
        uploadTitle: 'Sube un recuerdo del aniversario',
        uploadDescription: 'Comparte una foto, video o nota para esta fecha.',
      );
    case 'baby_shower':
      return const EventThemeCopy(
        emoji: '🍼',
        label: 'Baby shower',
        guestTitle: 'Recuerdos del baby shower',
        guestDescription:
            'Guarda mensajes, fotos y videos para dar la bienvenida al bebé.',
        uploadTitle: 'Sube un recuerdo del baby shower',
        uploadDescription:
            'Agrega fotos, videos o una nota llena de buenos deseos.',
      );
    case 'corporate':
      return const EventThemeCopy(
        emoji: '🏢',
        label: 'Evento',
        guestTitle: 'Momentos del evento',
        guestDescription:
            'Reúne fotos, videos y notas de los asistentes en un solo lugar.',
        uploadTitle: 'Sube contenido del evento',
        uploadDescription: 'Comparte fotos, videos o una nota del momento.',
      );
    case 'party':
      return const EventThemeCopy(
        emoji: '🎉',
        label: 'Fiesta',
        guestTitle: 'Recuerdos de la fiesta',
        guestDescription:
            'Comparte los mejores momentos, videos y mensajes de la fiesta.',
        uploadTitle: 'Sube un recuerdo de la fiesta',
        uploadDescription: 'Agrega fotos, videos o una nota para el álbum.',
      );
    case 'travel':
      return const EventThemeCopy(
        emoji: '✈️',
        label: 'Viaje',
        guestTitle: 'Recuerdos del viaje',
        guestDescription:
            'Guarda paisajes, momentos y notas de esta experiencia.',
        uploadTitle: 'Sube un recuerdo del viaje',
        uploadDescription: 'Comparte fotos, videos o una nota de la aventura.',
      );
    default:
      return const EventThemeCopy(
        emoji: '📸',
        label: 'Álbum',
        guestTitle: 'Recuerdos del álbum',
        guestDescription:
            'Comparte fotos, videos y notas para conservar este momento.',
        uploadTitle: 'Sube tus recuerdos',
        uploadDescription:
            'Elige fotos, videos o una nota para aportar al álbum.',
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
