import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:dealker_app/features/sell_phone/presentation/sell_ui.dart';

/// Finds a 15-digit IMEI in whatever a barcode/QR holds (IMEI labels often carry two numbers).
String? imeiFromScan(String raw) {
  final RegExp r = RegExp(r'(?<!\d)\d{15}(?!\d)');
  return r.firstMatch(raw)?.group(0);
}

/// Camera scanner for the IMEI barcode on the box / the phone's `*#06#` QR. Pops with the IMEI.
class ImeiScannerScreen extends StatefulWidget {
  const ImeiScannerScreen({super.key});

  @override
  State<ImeiScannerScreen> createState() => _ImeiScannerScreenState();
}

class _ImeiScannerScreenState extends State<ImeiScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[
      BarcodeFormat.code128,
      BarcodeFormat.qrCode,
      BarcodeFormat.code39,
    ],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture c) {
    if (_done) return;
    for (final Barcode b in c.barcodes) {
      final String? imei = imeiFromScan(b.rawValue ?? '');
      if (imei != null) {
        _done = true;
        Navigator.of(context).pop(imei);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (BuildContext context, MobileScannerException e) =>
                  Center(
                child: Padding(
                  padding: EdgeInsets.all(28.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.no_photography_rounded,
                        color: Colors.white70,
                        size: 44.sp,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        e.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Camera access is off. Allow it in Settings, or type the IMEI instead.'
                            : 'The camera is not available. Type the IMEI instead.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4.h,
              left: 4.w,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Center(
              child: Container(
                width: 260.w,
                height: 190.h,
                decoration: BoxDecoration(
                  border: Border.all(color: ReturnColors.canvas, width: 3),
                  borderRadius: BorderRadius.circular(18.r),
                ),
              ),
            ),
            Positioned(
              left: 24.w,
              right: 24.w,
              bottom: 36.h,
              child: Text(
                'Point the camera at the IMEI barcode on the box, or at the QR code shown when you dial *#06#.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontSize: 13.sp, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
