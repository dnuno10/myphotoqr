import '../core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  Future<void> sendOtp(String email) async {
    await supabase.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: null,
    );
  }

  Future<void> verifyOtp({required String email, required String token}) async {
    await supabase.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim(),
      token: token.trim(),
    );

    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('users').upsert({
      'auth_user_id': user.id,
      'email': user.email,
      'full_name': user.userMetadata?['full_name'],
    }, onConflict: 'auth_user_id');
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
