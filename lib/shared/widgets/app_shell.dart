import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../services/auth_service.dart';
import 'logo_mark.dart';

enum ShellSection { dashboard, albums, create, pricing }

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.current, required this.child});

  final ShellSection current;
  final Widget child;

  static const _bg = Color(0xFFFAFAFB);

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) context.go('/login');
  }

  void _go(BuildContext context, ShellSection section) {
    switch (section) {
      case ShellSection.dashboard:
        context.go('/');
      case ShellSection.albums:
        context.go('/albums');
      case ShellSection.create:
        context.go('/create');
      case ShellSection.pricing:
        context.go('/pricing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;

        final sidebar = _Sidebar(
          current: current,
          onSelect: (s) => _go(context, s),
          onSignOut: () => _signOut(context),
        );

        if (compact) {
          return Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const LogoMark(size: 30),
                  const SizedBox(width: 10),
                  const Text(
                    'MyPhotoQR',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ],
              ),
              actions: const [_UserChip(compact: true), SizedBox(width: 8)],
            ),
            drawer: Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(child: sidebar),
            ),
            body: SafeArea(child: child),
          );
        }

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(width: 264, child: sidebar),
                Expanded(
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(24, 14, 32, 0),
                          child: _UserChip(),
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.onSelect,
    required this.onSignOut,
  });

  final ShellSection current;
  final ValueChanged<ShellSection> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFEDEDF1))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                LogoMark(
                  size: 40,
                  onTap: () => onSelect(ShellSection.dashboard),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'MyPhotoQR',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: Color(0xFF15151A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Dashboard',
            active: current == ShellSection.dashboard,
            onTap: () => onSelect(ShellSection.dashboard),
          ),
          _NavItem(
            icon: Icons.photo_library_outlined,
            label: 'Albums',
            active: current == ShellSection.albums,
            onTap: () => onSelect(ShellSection.albums),
          ),
          _NavItem(
            icon: Icons.add_rounded,
            label: 'Create Album',
            active: current == ShellSection.create,
            onTap: () => onSelect(ShellSection.create),
          ),
          _NavItem(
            icon: Icons.sell_outlined,
            label: 'Pricing',
            active: current == ShellSection.pricing,
            onTap: () => onSelect(ShellSection.pricing),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            active: false,
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF15151A) : const Color(0xFF6A6A74);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? const Color(0xFFF3F4F6) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final scaffold = Scaffold.maybeOf(context);
            if (scaffold?.hasDrawer ?? false) {
              if (scaffold!.isDrawerOpen) Navigator.of(context).pop();
            }
            onTap();
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({this.compact = false});

  final bool compact;

  String _displayName() {
    final user = supabase.auth.currentUser;
    final meta = user?.userMetadata?['full_name']?.toString().trim() ?? '';
    if (meta.isNotEmpty) return meta;
    final email = user?.email ?? '';
    return email.contains('@') ? email.split('@').first : 'Account';
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final parts = name
        .split(RegExp(r'[\s._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => p[0].toUpperCase()).join();

    final avatar = CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF15151A),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      color: Colors.white,
      onSelected: (value) async {
        if (value == 'signout') {
          await AuthService().signOut();
          if (context.mounted) context.go('/login');
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'signout', child: Text('Sign out')),
      ],
      child: compact
          ? avatar
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15151A),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
              ],
            ),
    );
  }
}
