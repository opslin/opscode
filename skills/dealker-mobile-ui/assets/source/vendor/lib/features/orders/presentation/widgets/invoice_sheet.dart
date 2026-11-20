import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';

typedef InvoiceUpload = ({XFile file, String number});

/// Bottom sheet asking the seller for their invoice (photo) before an order is packed.
/// Returns the picked file + optional invoice number, or null if dismissed.
Future<InvoiceUpload?> showInvoiceSheet(BuildContext context,
    {String? orderNumber}) {
  return showModalBottomSheet<InvoiceUpload>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (c) => _InvoiceSheet(orderNumber: orderNumber),
  );
}

class _InvoiceSheet extends StatefulWidget {
  const _InvoiceSheet({this.orderNumber});
  final String? orderNumber;

  @override
  State<_InvoiceSheet> createState() => _InvoiceSheetState();
}

class _InvoiceSheetState extends State<_InvoiceSheet> {
  final _number = TextEditingController();
  final _picker = ImagePicker();
  XFile? _file;
  Uint8List? _bytes;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await _picker.pickImage(
          source: source, imageQuality: 85, maxWidth: 2200);
      if (f == null) return;
      final b = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _file = f;
        _bytes = b;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the photo. Please try again.');
      }
    }
  }

  void _submit() {
    if (_file == null) {
      setState(() => _error = 'Add a clear photo of your invoice to continue');
      return;
    }
    Navigator.pop(context, (file: _file!, number: _number.text.trim()));
  }

  Widget _tile(IconData icon, String label, ImageSource src) => Expanded(
        child: GestureDetector(
          onTap: () => _pick(src),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(children: [
              Icon(icon, size: 26, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            18, 10, 18, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD9DEEA),
                          borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 14),
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5EEFF),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(PhosphorIconsFill.receipt,
                      size: 28, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upload your invoice', style: heading(size: 20)),
                        const SizedBox(height: 2),
                        Text(
                            widget.orderNumber == null
                                ? 'Required before you pack. The invoice goes with the parcel.'
                                : 'Required before you pack ${widget.orderNumber}. The invoice goes with the parcel.',
                            style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.textMuted)),
                      ]),
                ),
              ]),
              const SizedBox(height: 16),
              if (_bytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(children: [
                    Image.memory(_bytes!,
                        height: 190, width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _file = null;
                          _bytes = null;
                        }),
                        child: const CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close,
                                size: 18, color: Colors.white)),
                      ),
                    ),
                  ]),
                )
              else
                Row(children: [
                  _tile(PhosphorIconsFill.camera, 'Take photo',
                      ImageSource.camera),
                  const SizedBox(width: 10),
                  _tile(PhosphorIconsFill.image, 'From gallery',
                      ImageSource.gallery),
                ]),
              const SizedBox(height: 14),
              TextField(
                controller: _number,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Invoice number (optional)',
                  hintStyle: const TextStyle(
                      fontSize: 13.5, color: AppColors.textMuted),
                  prefixIcon: const Icon(PhosphorIconsRegular.hash,
                      size: 20, color: AppColors.primary),
                  filled: true,
                  fillColor: const Color(0xFFF7F9FD),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(PhosphorIconsFill.warningCircle,
                      size: 16, color: AppColors.rose),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.rose)),
                  ),
                ]),
              ],
              const SizedBox(height: 18),
              AuctionButton(
                  label: 'Upload & continue',
                  icon: PhosphorIconsFill.uploadSimple,
                  onPressed: _submit),
            ]),
      ),
    );
  }
}
