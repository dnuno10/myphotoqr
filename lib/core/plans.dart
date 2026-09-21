import 'app_config.dart';

enum AlbumPlan { basic, premium }

class PlanInfo {
  const PlanInfo({
    required this.plan,
    required this.name,
    required this.price,
    required this.tagline,
    required this.retentionDays,
    required this.priceId,
    required this.features,
    this.popular = false,
  });

  final AlbumPlan plan;
  final String name;
  final double price;
  final String tagline;
  final int retentionDays;
  final String priceId;
  final List<String> features;
  final bool popular;

  String get priceLabel => '\$${price.toStringAsFixed(2)}';
  String get id => plan.name;
}

class Plans {
  static const basic = PlanInfo(
    plan: AlbumPlan.basic,
    name: 'Basic',
    price: 9.99,
    tagline: 'Everything you need to collect memories.',
    retentionDays: 30,
    priceId: AppConfig.stripeAlbumPriceId,
    features: [
      '1 event album',
      'QR code and share links for guests',
      'Guest uploads from the browser',
      'Photos, videos, notes and audio memories',
      'Live gallery and live slideshow',
      'Up to 300 uploads',
      'Stored in the cloud for 30 days after the event',
      'Email support within 24–48 business hours',
    ],
  );

  static const premium = PlanInfo(
    plan: AlbumPlan.premium,
    name: 'Premium',
    price: 19.99,
    tagline: 'More room, more time and full control.',
    retentionDays: 90,
    priceId: AppConfig.stripePremiumPriceId,
    popular: true,
    features: [
      'Everything in Basic',
      'Unlimited uploads',
      'Full ZIP export of photos and videos',
      'Custom QR code',
      'No MyPhotoQR watermark',
      'Moderation tools: approve, hide or auto-approve',
      'Stored in the cloud for 90 days after the event',
      'Priority email support',
    ],
  );

  static const all = [basic, premium];

  static PlanInfo byId(String? id) {
    return all.firstWhere((p) => p.id == id, orElse: () => basic);
  }

  // Add-on: keep the album in the cloud year after year.
  static const archivePrice = 49.99;
  static const archivePriceLabel = '\$49.99';
  static const archiveGraceDays = 30;
}
