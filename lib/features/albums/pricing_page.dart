import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/plans.dart';
import '../../shared/widgets/app_shell.dart';
import 'album_card.dart';

const _ink = Color(0xFF15151A);
const _pink = Color(0xFFE11D48);

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      current: ShellSection.pricing,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;

          final cards = [
            for (final plan in Plans.all)
              _PlanCard(
                plan: plan,
                onSelect: () => context.go('/create?plan=${plan.id}'),
              ),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Simple, one-time pricing',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pay once per album. No subscription unless you want to keep it in the cloud.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF6A6A74)),
                    ),
                    const SizedBox(height: 28),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 20),
                          Expanded(child: cards[1]),
                        ],
                      )
                    else ...[
                      cards[1],
                      const SizedBox(height: 20),
                      cards[0],
                    ],
                    const SizedBox(height: 20),
                    const _ArchiveAddOn(),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onSelect});

  final PlanInfo plan;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final highlighted = plan.popular;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        DashCard(
          padding: const EdgeInsets.all(28),
          borderColor: highlighted ? _pink : const Color(0xFFEDEDF1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                plan.tagline,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF6A6A74),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        plan.priceLabel,
                        style: const TextStyle(
                          fontSize: 52,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'USD / album',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6A6A74),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: highlighted
                        ? _pink
                        : const Color(0xFF0B0B10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Choose ${plan.name}'),
                ),
              ),
              const SizedBox(height: 22),
              for (final f in plan.features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3F3F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (highlighted)
          Positioned(
            top: -13,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _pink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'MOST POPULAR',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ArchiveAddOn extends StatelessWidget {
  const _ArchiveAddOn();

  @override
  Widget build(BuildContext context) {
    return DashCard(
      padding: const EdgeInsets.all(26),
      color: const Color(0xFFF8F7FF),
      borderColor: const Color(0xFFE4E0FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: Color(0xFF6D28D9)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Add-on: Permanent archive',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text:
                      'Keep your event in the cloud without losing anything for ',
                ),
                TextSpan(
                  text: '${Plans.archivePriceLabel} / year',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.45,
              color: Color(0xFF3F3F46),
            ),
          ),
          const SizedBox(height: 12),
          for (final line in [
            'Add it at checkout on top of Basic or Premium.',
            "If you don't renew, your album is removed after a ${Plans.archiveGraceDays}-day grace period. Export it anytime as a ZIP.",
            'We remind you 30, 7 and 1 day before it expires.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Color(0xFF6D28D9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Color(0xFF52525B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
