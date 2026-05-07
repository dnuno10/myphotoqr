import '../core/supabase_client.dart';

class GuestSessionService {
  Future<void> ensureSignedIn() async {
    if (supabase.auth.currentSession != null) return;
    await supabase.auth.signInAnonymously();
  }
}
