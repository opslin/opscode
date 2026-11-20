import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

class RootDetection {
  RootDetection._();

  static const MethodChannel _channel = MethodChannel('dealker/security');

  static Future<bool> blockIfCompromised(BuildContext context) async {
    if (kIsWeb) {
      return false;
    }
    final compromised = await _isCompromised();
    if (!compromised) {
      return false;
    }

    if (!context.mounted) {
      return true;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Security Warning'),
          content: const Text(
            'Dealkr cannot run on rooted/jailbroken devices.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return true;
  }

  static Future<bool> _isCompromised() async {
    try {
      final rooted = await FlutterJailbreakDetection.jailbroken;
      return rooted;
    } catch (_) {
      if (Platform.isAndroid) {
        try {
          return await _channel.invokeMethod<bool>('isDeviceCompromised') ??
              false;
        } catch (_) {
          return false;
        }
      }
      return false;
    }
  }
}
