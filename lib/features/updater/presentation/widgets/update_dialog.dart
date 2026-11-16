import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/theme/app_theme.dart';

enum _UpdateDialogStatus { idle, downloading, installing, error }

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.releaseInfo,
    this.isManualCheck = false,
  });

  final AppReleaseInfo releaseInfo;
  final bool isManualCheck;

  static Future<void> show(
    BuildContext context, {
    required AppReleaseInfo releaseInfo,
    bool isManualCheck = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        releaseInfo: releaseInfo,
        isManualCheck: isManualCheck,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final AppUpdateService _updateService = sl<AppUpdateService>();
  _UpdateDialogStatus _status = _UpdateDialogStatus.idle;
  DownloadProgress? _progress;
  String? _errorMessage;
  StreamSubscription<DownloadProgress>? _downloadSub;

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _status = _UpdateDialogStatus.downloading;
      _errorMessage = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final destinationPath = '${tempDir.path}/DevDeck-update.apk';

      _downloadSub = _updateService
          .downloadApk(widget.releaseInfo.apkDownloadUrl, destinationPath)
          .listen(
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _status = _UpdateDialogStatus.error;
              _errorMessage = err.toString();
            });
          }
        },
        onDone: () async {
          if (mounted) {
            setState(() {
              _status = _UpdateDialogStatus.installing;
            });
          }
          try {
            await _updateService.installApk(destinationPath);
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _status = _UpdateDialogStatus.error;
                _errorMessage = 'Could not open package installer: $e';
              });
            }
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _UpdateDialogStatus.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onLater() {
    if (!widget.isManualCheck) {
      _updateService.snoozeUpdate(widget.releaseInfo.version);
    }
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            if (_status == _UpdateDialogStatus.idle) ...[
              _buildChangelogSection(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ] else if (_status == _UpdateDialogStatus.downloading) ...[
              _buildDownloadingSection(),
            ] else if (_status == _UpdateDialogStatus.installing) ...[
              _buildInstallingSection(),
            ] else if (_status == _UpdateDialogStatus.error) ...[
              _buildErrorSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.system_update_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Update Available',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      widget.releaseInfo.tagName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  if (widget.releaseInfo.formattedSize.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.releaseInfo.formattedSize,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChangelogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What's New:",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: SingleChildScrollView(
            child: Text(
              _cleanChangelog(widget.releaseInfo.changelog),
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _cleanChangelog(String raw) {
    // Clean up excessive markdown headings or commit hashes for clean in-app display
    return raw
        .replaceAll(RegExp(r'##\s*'), '')
        .replaceAll(RegExp(r'\*\*Full Changelog\*\*:.*'), '')
        .trim();
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _onLater,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.white.withOpacity(0.12)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Later',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _startDownloadAndInstall,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Update Now',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingSection() {
    final progressVal = _progress?.progress ?? 0.0;
    final percent = _progress?.percentage ?? 0;
    final receivedMb = _progress?.receivedMb ?? '0.0';
    final totalMb = _progress?.totalMb ?? widget.releaseInfo.formattedSize;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Downloading package...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressVal > 0 ? progressVal : null,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$receivedMb MB / $totalMb',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallingSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          SizedBox(width: 14),
          Text(
            'Launching Android Package Installer...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Text(
            _errorMessage ?? 'An error occurred during update.',
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _startDownloadAndInstall,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

