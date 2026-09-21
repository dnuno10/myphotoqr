import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/album.dart';
import '../../services/album_service.dart';
import '../../shared/ui/safe_user_messages.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import 'album_card.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  late final Future<List<Album>> _future = AlbumService().getMyAlbums();

  @override
  Widget build(BuildContext context) {
    return AppShell(
      current: ShellSection.albums,
      child: FutureBuilder<List<Album>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          if (snapshot.hasError) {
            return ErrorView(
              message: safeUserErrorMessage(
                snapshot.error,
                fallback: 'We could not load your albums. Please try again.',
              ),
            );
          }

          final albums = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Albums',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: Color(0xFF15151A),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.go('/create'),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Create album'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Open an album to manage uploads, QR access and guest memories.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF6A6A74)),
                    ),
                    const SizedBox(height: 22),
                    if (albums.isEmpty)
                      DashCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 40),
                            const SizedBox(height: 12),
                            const Text(
                              'No albums yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context.go('/create'),
                              child: const Text('Create your first album'),
                            ),
                          ],
                        ),
                      )
                    else
                      AlbumGrid(albums: albums),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
