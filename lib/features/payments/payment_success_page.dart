import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/payment_service.dart';
import '../../shared/widgets/logo_mark.dart';

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({super.key, required this.sessionId});

  final String? sessionId;

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final _paymentService = PaymentService();

  bool _loading = true;
  String? _error;
  String? _message;
  int _attempts = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    if (widget.sessionId == null || widget.sessionId!.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing checkout session ID.';
      });
      return;
    }

    _checkPayment();

    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkPayment();
    });
  }

  Future<void> _checkPayment() async {
    if (_attempts >= 20) {
      _timer?.cancel();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Payment was received, but the album is still being prepared. Please return to the dashboard and refresh.';
      });

      return;
    }

    _attempts++;

    try {
      final result = await _paymentService.getCheckoutAlbumResult(
        sessionId: widget.sessionId!.trim(),
      );

      if (!mounted) return;

      if (result.isReady) {
        _timer?.cancel();
        context.go('/album/${result.albumId}');
        return;
      }

      if (result.isFailed) {
        _timer?.cancel();

        setState(() {
          _loading = false;
          _error = 'The payment could not be completed.';
        });

        return;
      }

      setState(() {
        _message = result.message ?? 'Preparing your album...';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = 'Waiting for confirmation...';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Container(
            width: 430,
            padding: const EdgeInsets.fromLTRB(34, 34, 34, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoMark(size: 54),
                const SizedBox(height: 20),
                Text(
                  _error == null ? 'Payment confirmed' : 'Payment status',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF15151A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _error ??
                      _message ??
                      'We are creating your album. This may take a few seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.52),
                  ),
                ),
                const SizedBox(height: 26),
                if (_loading && _error == null)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Go to dashboard'),
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
