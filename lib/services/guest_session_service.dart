import '../core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestSessionService {
  Future<void> ensureSignedIn() async {
    if (supabase.auth.currentSession != null) return;
    try {
      await supabase.auth.signInAnonymously();
    } on AuthApiException catch (e) {
      if (e.code == 'anonymous_provider_disabled') {
        throw Exception(
          'Guest access requires Supabase Anonymous sign-ins. Enable it in Supabase Dashboard → Authentication → Providers → Anonymous.',
        );
      }
      rethrow;
    }
  }
}
