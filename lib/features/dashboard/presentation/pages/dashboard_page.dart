import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../connection/presentation/bloc/connection_bloc.dart';
import '../../../connection/presentation/bloc/connection_event.dart';
import '../../../connection/presentation/bloc/connection_state.dart';
import 'package:devdeck/features/clipboard/presentation/bloc/clipboard_bloc.dart';
import 'package:devdeck/features/clipboard/presentation/bloc/clipboard_event.dart';
import 'package:devdeck/features/clipboard/presentation/bloc/clipboard_state.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    final connectionState = context.read<ConnectionBloc>().state;
    if (connectionState.status == ConnectionStatus.connected) {
      context.read<ClipboardBloc>().add(ClipboardStartSync());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/devdeck-logo-icon.webp',
              height: 22,
              width: 22,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text(
              'DEVDECK',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          // Settings glass button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white70),
              onPressed: () => context.push('/settings'),
            ),
          ),
          // Disconnect glass button
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
            ),
            child: IconButton(
              icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
              tooltip: 'Disconnect',
              onPressed: () => _showLogoutDialog(context),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF080B11),
              Color(0xFF0D121F),
              Color(0xFF06090E),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: BlocListener<ConnectionBloc, ConnectionBlocState>(
          listener: (context, state) {
            if (state.status == ConnectionStatus.connected) {
              context.read<ClipboardBloc>().add(ClipboardStartSync());
            } else {
              context.read<ClipboardBloc>().add(ClipboardStopSync());
            }
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Connection Status Card (breathing pulsing style)
                const ConnectionStatusCard(),
                const SizedBox(height: 18),
    
                // 2. Live Clipboard Monitor Terminal
                const ClipboardStatusCard(),
                const SizedBox(height: 24),
    
                // 3. Section Title: Console Hub
                const Text(
                  'CONSOLE INTERFACES',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
    
                // 4. Virtual Stream Deck Hero Panel
                _buildStreamDeckHero(context),
                const SizedBox(height: 18),
    
                // 5. Category Launcher Modules List
                _buildCategoryList(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreamDeckHero(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/stream-deck');
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.04),
                  const Color(0xFF6366F1).withOpacity(0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Advanced micro grid simulating keycaps
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: index == 4
                              ? const Color(0xFF6366F1).withOpacity(0.8)
                              : Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.15)),
                        ),
                        child: const Text(
                          'PRIMARY CONSOLE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Virtual Stream Deck',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Unified control center for all actions',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white30,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.85)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Quick App Launcher', Icons.rocket_launch_rounded, const Color(0xFF6366F1)),
        const SizedBox(height: 8),
        _buildCategoryCard(
          context,
          title: 'App Shortcuts',
          subtitle: 'VS Code, Chrome, Terminal, etc.',
          icon: Icons.rocket_launch_rounded,
          accentColor: const Color(0xFF6366F1),
          route: '/apps',
        ),
        const SizedBox(height: 20),

        _buildSectionHeader('Website Shortcuts', Icons.language_rounded, const Color(0xFFF59E0B)),
        const SizedBox(height: 8),
        _buildCategoryCard(
          context,
          title: 'URL Shortcuts',
          subtitle: 'GitHub, ChatGPT, Gmail, etc.',
          icon: Icons.language_rounded,
          accentColor: const Color(0xFFF59E0B),
          route: '/websites',
        ),
        const SizedBox(height: 20),

        _buildSectionHeader('Workspace Profiles', Icons.workspaces_rounded, const Color(0xFF10B981)),
        const SizedBox(height: 8),
        _buildCategoryCard(
          context,
          title: 'Workspace Flows',
          subtitle: 'Full development environments',
          icon: Icons.workspaces_rounded,
          accentColor: const Color(0xFF10B981),
          route: '/workspaces',
        ),
        const SizedBox(height: 20),

        _buildSectionHeader('Gesture Controller Pad', Icons.gesture_rounded, const Color(0xFF8B5CF6)),
        const SizedBox(height: 8),
        _buildCategoryCard(
          context,
          title: 'Interactive Gesture Pad',
          subtitle: 'Swipe or tap here to trigger desktop macros',
          icon: Icons.touch_app_rounded,
          accentColor: const Color(0xFF8B5CF6),
          route: '/gesture-pad',
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String route,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(route);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.04),
                  accentColor.withOpacity(0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: accentColor.withOpacity(0.9), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white30,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke Device Pairing?'),
        content: const Text(
          'This will remove all stored keys and disconnect the remote connection from your PC.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(AuthLogoutRequested());
              context.go('/pairing');
            },
            child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// PULSING INDICATOR FOR HIGH-END CONNECTION SYSTEM
// ----------------------------------------------------
class PulsingStatusDot extends StatefulWidget {
  final Color color;
  const PulsingStatusDot({super.key, required this.color});

  @override
  State<PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<PulsingStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4 + (_controller.value * 0.6)),
                blurRadius: 4 + (_controller.value * 8),
                spreadRadius: _controller.value * 1.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionBloc, ConnectionBlocState>(
      builder: (context, state) {
        final status = state.status;
        
        Color statusColor;
        String statusText;
        IconData statusIcon;
        List<Color> gradientColors;

        switch (status) {
          case ConnectionStatus.connected:
            statusColor = AppTheme.secondaryColor;
            statusText = 'CONNECTED';
            statusIcon = Icons.wifi_rounded;
            gradientColors = [const Color(0xFF0F172A), const Color(0xFF0F172A)];
            break;
          case ConnectionStatus.connecting:
            statusColor = Colors.orangeAccent;
            statusText = 'CONNECTING...';
            statusIcon = Icons.sync;
            gradientColors = [const Color(0xFF0F172A), const Color(0xFF0F172A)];
            break;
          case ConnectionStatus.disconnected:
            statusColor = Colors.redAccent;
            statusText = 'DISCONNECTED';
            statusIcon = Icons.wifi_off_rounded;
            gradientColors = [const Color(0xFF0F172A), const Color(0xFF0F172A)];
            break;
          case ConnectionStatus.pairingRequired:
            statusColor = AppTheme.primaryColor;
            statusText = 'PAIRING REQUIRED';
            statusIcon = Icons.phonelink_lock_rounded;
            gradientColors = [const Color(0xFF0F172A), const Color(0xFF0F172A)];
            break;
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  // High tech connector badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                    ),
                    child: status == ConnectionStatus.connecting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            ),
                          )
                        : Icon(statusIcon, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            PulsingStatusDot(color: statusColor),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status == ConnectionStatus.connected
                              ? 'Telemetry connection active'
                              : status == ConnectionStatus.pairingRequired
                                  ? 'Device requires PC validation code'
                                  : 'Waiting for network PC socket',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status == ConnectionStatus.disconnected)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                      onPressed: () {
                        context.read<ConnectionBloc>().add(ConnectionReconnectRequested());
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
class ClipboardStatusCard extends StatelessWidget {
  const ClipboardStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClipboardBloc, ClipboardState>(
      builder: (context, state) {
        String pcText = 'No content synced yet';
        String phoneText = 'No content copied yet';
        bool isSyncStopped = state is ClipboardSyncStopped;
        bool hasPcData = false;
        bool hasPhoneData = false;

        if (state is ClipboardSyncing) {
          if (state.lastPcContent != null && state.lastPcContent!.isNotEmpty) {
            pcText = state.lastPcContent!;
            hasPcData = true;
          }
          if (state.lastPhoneContent != null && state.lastPhoneContent!.isNotEmpty) {
            phoneText = state.lastPhoneContent!;
            hasPhoneData = true;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Terminal Title bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSyncStopped ? Colors.redAccent : Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CLIPBOARD TRANSCEIVER',
                        style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isSyncStopped ? 'SYNC DISABLED' : 'SYNC ACTIVE',
                    style: TextStyle(
                      color: isSyncStopped ? Colors.redAccent.withOpacity(0.8) : Theme.of(context).primaryColor.withOpacity(0.8),
                      fontFamily: 'monospace',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // SECTION 1: PC Clipboard (Incoming)
              _buildClipboardSection(
                context,
                title: 'RECEIVED FROM PC',
                content: pcText,
                icon: Icons.desktop_windows_rounded,
                accentColor: const Color(0xFF10B981), // Emerald green
                onCopy: () => _copyToClipboard(context, pcText, 'Copied PC text to phone'),
                showActions: !isSyncStopped && hasPcData,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(color: Colors.white10, height: 1),
              ),

              // SECTION 2: Phone Clipboard (Outgoing)
              _buildClipboardSection(
                context,
                title: 'COPIED FROM PHONE',
                content: phoneText,
                icon: Icons.phone_android_rounded,
                accentColor: const Color(0xFF6366F1), // Indigo
                onCopy: () => _copyToClipboard(context, phoneText, 'Copied phone text'),
                showActions: !isSyncStopped && hasPhoneData,
                isOutgoing: true,
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.2)),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildClipboardSection(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onCopy,
    required bool showActions,
    bool isOutgoing = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white60),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (showActions && isOutgoing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Text(
                  'SYNCED TO PC',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.02)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ),
            if (showActions) ...[
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: IconButton(
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.copy_all_rounded, color: accentColor, size: 18),
                  tooltip: 'Copy text',
                  onPressed: onCopy,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
