class AppConfig {
  static const String supabaseUrl = 'https://ozgycqyiizxzgltrimjf.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96Z3ljcXlpaXp4emdsdHJpbWpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2NzAxNDgsImV4cCI6MjA5MzI0NjE0OH0.TRc8XzaCq41XAc3sqoJDFeLxWbiKvZCtqramaJQE3oQ';

  static const String appPublicBaseUrl = 'https://app.myphotoqr.com';

  static const String stripeProductId = 'prod_URHidzkDgUyTy6';

  // Replace this with your real Stripe Price ID.
  // It should look like: price_123...
  static const String stripeAlbumPriceId = 'price_1TSP9P30JQkRaV5jlFYaE8Ov';

  static const String albumMediaBucket = 'album-media';

  static const String paymentSuccessUrl =
      '$appPublicBaseUrl/payment-success?session_id={CHECKOUT_SESSION_ID}';

  static const String paymentCancelUrl = '$appPublicBaseUrl/create';
}
