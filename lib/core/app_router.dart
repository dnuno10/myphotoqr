import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/albums/dashboard_page.dart';
import '../features/albums/create_album_page.dart';
import '../features/albums/album_admin_page.dart';
import '../features/albums/album_settings_page.dart';
import '../features/payments/payment_success_page.dart';
import '../features/public_album/public_album_page.dart';
import '../features/public_album/upload_memory_page.dart';
import '../features/slideshow/slideshow_page.dart';
import 'supabase_client.dart';
import 'app_theme.dart';

class AppRouter {
  static final router = GoRouter(
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final location = state.matchedLocation;

      final isLogin = location == '/login';
      final isPublicAlbum = location.startsWith('/a/');
      final isSlideshow = location.startsWith('/slideshow/');
      final isPaymentSuccess = location == '/payment-success';

      // Estas rutas deben poder abrir sin que el redirect las mande al login/dashboard.
      if (isPublicAlbum || isSlideshow || isPaymentSuccess) {
        return null;
      }

      if (session == null && !isLogin) {
        return '/login';
      }

      if (session != null && isLogin) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) =>
            Theme(data: AppTheme.login, child: const LoginPage()),
      ),
      GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
      GoRoute(path: '/create', builder: (_, __) => const CreateAlbumPage()),
      GoRoute(
        path: '/payment-success',
        builder: (_, state) {
          final sessionId = state.uri.queryParameters['session_id'];

          return PaymentSuccessPage(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/album/:id',
        builder: (_, state) =>
            AlbumAdminPage(albumId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/album/:id/settings',
        builder: (_, state) =>
            AlbumSettingsPage(albumId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/a/:slug',
        builder: (_, state) =>
            PublicAlbumPage(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/a/:slug/upload',
        builder: (_, state) =>
            UploadMemoryPage(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/slideshow/:slug',
        builder: (_, state) =>
            SlideshowPage(slug: state.pathParameters['slug']!),
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
