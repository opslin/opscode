import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/nav_button/presentation/providers/nav_button_provider.dart';

/// Full-screen embedded destination for a WEBVIEW nav button — a website
/// or a game, taking over the whole screen the way an in-app event page
/// does in apps like this one's design was modeled on. Deliberately no
/// bottom nav bar and no app bar of this app's own chrome, only a small
/// floating close control, so the destination page genuinely reads as its
/// own full-screen experience rather than a cramped panel inside Dealkr.
class NavButtonWebviewScreen extends ConsumerStatefulWidget {
  const NavButtonWebviewScreen({
    required this.url,
    this.passIdentity = false,
    super.key,
  });

  final String url;
  final bool passIdentity;

  @override
  ConsumerState<NavButtonWebviewScreen> createState() =>
      _NavButtonWebviewScreenState();
}

class _NavButtonWebviewScreenState
    extends ConsumerState<NavButtonWebviewScreen> {
  WebViewController? _controller;
  String? _webTarget;
  bool _loading = true;
  bool _resolvingIdentity;

  _NavButtonWebviewScreenState() : _resolvingIdentity = false;

  @override
  void initState() {
    super.initState();
    _resolvingIdentity = widget.passIdentity;
    if (!kIsWeb)
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _loading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
          ),
        );
    unawaited(_load());
  }

  Future<void> _load() async {
    var target = widget.url;
    final configuredUri = Uri.tryParse(target);
    if (kIsWeb &&
        widget.passIdentity &&
        (configuredUri?.scheme != 'https' ||
            configuredUri?.host.isEmpty != false)) {
      if (mounted) setState(() => _resolvingIdentity = false);
      return;
    }
    if (widget.passIdentity) {
      try {
        final token =
            await ref.read(navButtonRemoteDataSourceProvider).getWebviewToken();
        if (token != null && token.isNotEmpty) {
          final uri = Uri.parse(widget.url);
          target = uri.replace(
            queryParameters: <String, String>{
              ...uri.queryParameters,
              'dealker_token': token,
            },
          ).toString();
        }
      } catch (_) {
        // Identity handoff is best-effort — the destination still loads,
        // it just won't be able to identify the customer automatically.
      }
    }
    if (!mounted) return;
    if (kIsWeb) {
      setState(() {
        _webTarget = target;
        _resolvingIdentity = false;
      });
      return;
    }
    setState(() => _resolvingIdentity = false);
    await _controller!.loadRequest(Uri.parse(target));
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final uri = Uri.tryParse(_webTarget ?? '');
      final valid = uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty;
      return Scaffold(
        appBar: AppBar(title: const Text('Open website')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.open_in_new, size: 44),
              const SizedBox(height: 16),
              Text(_resolvingIdentity
                  ? 'Preparing your link…'
                  : valid
                      ? 'Continue to ${uri.host}'
                      : 'This link is unavailable.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: !valid || _resolvingIdentity
                    ? null
                    : () async {
                        final opened =
                            await launchUrl(uri, webOnlyWindowName: '_blank');
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Could not open the website.')));
                        }
                      },
                child: const Text('Open website'),
              ),
            ]),
          ),
        ),
      );
    }
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              if (!_resolvingIdentity) WebViewWidget(controller: _controller!),
              if (_loading || _resolvingIdentity)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.orderViolet,
                  ),
                ),
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
