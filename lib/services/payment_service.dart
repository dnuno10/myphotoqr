import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../core/supabase_client.dart';

class AlbumCheckoutDraft {
  const AlbumCheckoutDraft({
    required this.title,
    required this.eventType,
    required this.codeProtected,
    this.description,
    this.eventDate,
    this.eventLocation,
    this.themeColor = '#111827',
    this.themeBackgroundColor = '#ffffff',
    this.themeColorMode = 'solid',
    this.themeColorGradient,
    this.themeBackgroundMode = 'solid',
    this.themeBackgroundGradient,
    this.themeEmoji,
    this.eventTypeLabel,
    this.guestCode,
  });

  final String title;
  final String eventType;
  final bool codeProtected;
  final String? description;
  final DateTime? eventDate;
  final String? eventLocation;
  final String themeColor;
  final String themeBackgroundColor;
  final String themeColorMode;
  final Map<String, dynamic>? themeColorGradient;
  final String themeBackgroundMode;
  final Map<String, dynamic>? themeBackgroundGradient;
  final String? themeEmoji;
  final String? eventTypeLabel;
  final String? guestCode;

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'description': description?.trim(),
      'event_type': eventType,
      'event_date': eventDate?.toIso8601String().substring(0, 10),
      'event_location': eventLocation?.trim(),
      'event_type_label': eventTypeLabel?.trim(),
      'theme_emoji': themeEmoji?.trim(),
      'theme_color': themeColor,
      'theme_background_color': themeBackgroundColor,
      'theme_color_mode': themeColorMode,
      'theme_color_gradient': themeColorGradient,
      'theme_background_mode': themeBackgroundMode,
      'theme_background_gradient': themeBackgroundGradient,
      'code_protected': codeProtected,
      'guest_code': guestCode?.trim(),
    };
  }

  Map<String, String> toStripeMetadata() {
    final metadata = <String, String>{
      'album_title': title.trim(),
      'album_event_type': eventType,
      'album_theme_color': themeColor,
      'album_theme_background_color': themeBackgroundColor,
      'album_theme_color_mode': themeColorMode,
      'album_theme_background_mode': themeBackgroundMode,
      'album_code_protected': codeProtected ? 'true' : 'false',
    };

    if (themeColorMode == 'gradient' && themeColorGradient != null) {
      metadata['album_theme_color_gradient'] = jsonEncode(themeColorGradient);
    }

    if (themeBackgroundMode == 'gradient' && themeBackgroundGradient != null) {
      metadata['album_theme_background_gradient'] =
          jsonEncode(themeBackgroundGradient);
    }

    final label = (eventTypeLabel ?? '').trim();
    if (label.isNotEmpty) {
      metadata['album_event_type_label'] = label;
    }

    final emoji = (themeEmoji ?? '').trim();
    if (emoji.isNotEmpty) {
      metadata['album_theme_emoji'] = emoji;
    }

    final descriptionTrimmed = description?.trim();
    if (descriptionTrimmed != null && descriptionTrimmed.isNotEmpty) {
      metadata['album_description'] = descriptionTrimmed;
    }

    final locationTrimmed = eventLocation?.trim();
    if (locationTrimmed != null && locationTrimmed.isNotEmpty) {
      metadata['album_event_location'] = locationTrimmed;
    }

    final date = eventDate?.toIso8601String().substring(0, 10);
    if (date != null && date.isNotEmpty) {
      metadata['album_event_date'] = date;
    }

    // Intentionally exclude guest code from Stripe metadata.
    // If needed, a hash is computed client-side and sent as `album_guest_code_hash`.

    return metadata;
  }
}

class CheckoutAlbumResult {
  const CheckoutAlbumResult({required this.status, this.albumId, this.message});

  final String status;
  final String? albumId;
  final String? message;

  bool get isReady => albumId != null && albumId!.isNotEmpty;

  bool get isPending {
    return status == 'pending' || status == 'processing' || status == 'open';
  }

  bool get isFailed {
    return status == 'failed' ||
        status == 'canceled' ||
        status == 'cancelled' ||
        status == 'expired';
  }
}

class PaymentService {
  Future<void> startAlbumCheckout(AlbumCheckoutDraft draft) async {
    if (AppConfig.stripeAlbumPriceId.startsWith('price_REPLACE')) {
      throw Exception(
        'Missing Stripe Price ID. Add your price_... value in AppConfig.stripeAlbumPriceId.',
      );
    }

    String? guestCodeHash;
    if (draft.codeProtected &&
        (draft.guestCode?.trim().isNotEmpty ?? false)) {
      guestCodeHash = await supabase.rpc(
        'hash_guest_access_code',
        params: {'code': draft.guestCode!.trim()},
      ) as String;
    }

    final albumMetadata = draft.toStripeMetadata();
    if (guestCodeHash != null && guestCodeHash.isNotEmpty) {
      albumMetadata['album_guest_code_hash'] = guestCodeHash;
    }

    final response = await supabase.functions.invoke(
      'stripe-checkout-myphotoqr',
      body: {
        'mode': 'create_album',
        'price_id': AppConfig.stripeAlbumPriceId,
        'product_id': AppConfig.stripeProductId,
        'success_url': AppConfig.paymentSuccessUrl,
        'cancel_url': AppConfig.paymentCancelUrl,
        'album': albumMetadata,
      },
    );

    final data = response.data;

    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    if (data is! Map || data['url'] == null) {
      throw Exception('Checkout URL was not returned.');
    }

    final checkoutUrl = data['url'].toString();
    final uri = Uri.parse(checkoutUrl);

    final opened = await launchUrl(
      uri,
      webOnlyWindowName: '_self',
      mode: LaunchMode.platformDefault,
    );

    if (!opened) {
      throw Exception('Could not open Stripe Checkout.');
    }
  }

  Future<CheckoutAlbumResult> getCheckoutAlbumResult({
    required String sessionId,
  }) async {
    final response = await supabase.functions.invoke(
      'stripe-checkout-myphotoqr',
      body: {
        'mode': 'get_album_result',
        'session_id': sessionId,
      },
    );

    final data = response.data;

    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    if (data is! Map) {
      return const CheckoutAlbumResult(
        status: 'pending',
        message: 'Waiting for payment confirmation.',
      );
    }

    return CheckoutAlbumResult(
      status: (data['status']?.toString() ?? 'pending'),
      albumId: data['album_id']?.toString(),
      message: data['message']?.toString(),
    );
  }
}
