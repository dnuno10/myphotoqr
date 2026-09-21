class AppConfig {
  static const String supabaseUrl = 'https://ozgycqyiizxzgltrimjf.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96Z3ljcXlpaXp4emdsdHJpbWpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2NzAxNDgsImV4cCI6MjA5MzI0NjE0OH0.TRc8XzaCq41XAc3sqoJDFeLxWbiKvZCtqramaJQE3oQ';

  static const String appPublicBaseUrl = 'https://app.myphotoqr.com';

  static const String stripeProductId = 'prod_VC3G4ujmHp9uZk';

  // Replace this with your real Stripe Price ID.
  // It should look like: price_123...
  static const String stripeAlbumPriceId = 'price_1UBf9h3kPVs6fjFLaoNK5y7u';

  // Premium plan ($19.99, one-time). Product: prod_VIZOEGFMmybozl
  static const String stripePremiumPriceId = 'price_1UHyG63kPVs6fjFLBIPwCsSo';

  // Permanent archive add-on ($49.99 / year, recurring). Product: prod_VIZQxIJM5P3b6o
  static const String stripeArchivePriceId = 'price_1UHyHX3kPVs6fjFLC0DcN62Y';

  static const String albumMediaBucket = 'album-media';

  static const String paymentSuccessUrl =
      '$appPublicBaseUrl/payment-success?session_id={CHECKOUT_SESSION_ID}';

  static const String paymentCancelUrl = '$appPublicBaseUrl/create';
}
