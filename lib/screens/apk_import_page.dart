import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ApkImportPage extends StatefulWidget {
  const ApkImportPage({super.key});

  @override
  State<ApkImportPage> createState() => _ApkImportPageState();
}

class _ApkImportPageState extends State<ApkImportPage> {
  static const _channel = MethodChannel('com.example.exm1/apk_import');

  Map<String, dynamic>? _apk;
  bool _isPicking = false;
  String? _error;

  Future<void> _pickApk() async {
    if (_isPicking) return;
    setState(() {
      _isPicking = true;
      _error = null;
    });

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'pickAndInspectApk',
      );
      if (!mounted) return;
      if (result != null) setState(() => _apk = result);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message ?? 'خواندن فایل APK ناموفق بود.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'در پردازش فایل انتخاب‌شده خطایی رخ داد.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  String _formatBytes(dynamic value) {
    final bytes = (value as num?)?.toInt() ?? 0;
    if (bytes < 1024) return '$bytes بایت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} کیلوبایت';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} مگابایت';
  }

  @override
  Widget build(BuildContext context) {
    final apk = _apk;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت برنامه‌ها'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'افزودن برنامه',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            const Text(
              'فایل APK را از حافظه انتخاب کن تا مشخصات آن بررسی شود.',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 15, height: 1.7),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isPicking ? null : _pickApk,
              icon: _isPicking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open),
              label: Text(_isPicking ? 'در حال بررسی فایل...' : 'انتخاب فایل APK'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.right,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (apk != null) ...[
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildAppIcon(apk['iconBase64'] as String? ?? ''),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              apk['appName'] as String? ?? 'برنامه بدون نام',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      _detailRow('شناسه بسته', apk['packageName']),
                      _detailRow('نسخه', apk['versionName']),
                      _detailRow('کد نسخه', apk['versionCode']),
                      _detailRow('نام فایل', apk['fileName']),
                      _detailRow('حجم فایل', _formatBytes(apk['fileSize'])),
                      const SizedBox(height: 14),
                      const Text(
                        'فایل در فضای خصوصی برنامه نگهداری شده است. هنوز هیچ نسخه‌ای نصب یا تغییر داده نشده است.',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(String encoded) {
    Uint8List? bytes;
    if (encoded.isNotEmpty) {
      try {
        bytes = base64Decode(encoded);
      } on FormatException {
        bytes = null;
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: bytes == null
          ? Container(
              width: 60,
              height: 60,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.android, size: 34),
            )
          : Image.memory(bytes, width: 60, height: 60, fit: BoxFit.contain),
    );
  }

  Widget _detailRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              value?.toString() ?? '—',
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
