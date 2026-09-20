String safeUserErrorMessage(Object? error, {required String fallback}) {
  final raw = error?.toString().trim() ?? '';
  if (raw.isEmpty) return fallback;

  final lower = raw.toLowerCase();
  final internalMarkers = [
    'stripe',
    'supabase',
    'postgrest',
    'functionexception',
    'functions_exception',
    'clientexception',
    'socketexception',
    'xmlhttprequest',
    'http exception',
    'stack trace',
    'traceback',
    'secret',
    'token',
    'authorization',
    'apikey',
    'client_secret',
    'payment_intent',
    'setup_intent',
    'price_',
    'prod_',
    'cus_',
    'cs_',
    'pi_',
    'req_',
    'status:',
    'code:',
    'details:',
    'hint:',
    'localhost',
    '127.0.0.1',
    'edge function',
    'function was not found',
  ];

  if (internalMarkers.any(lower.contains)) return fallback;

  final simplified = raw
      .replaceFirst('Exception: ', '')
      .replaceFirst('Exception:', '')
      .trim();

  if (simplified.isEmpty) return fallback;
  if (simplified.length > 180) return fallback;

  return simplified;
}
