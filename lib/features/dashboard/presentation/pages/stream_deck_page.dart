import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/dependency_injection/injection_container.dart';

enum DeckKeyType { app, website, workspace }

class DeckKey {
  final String id;
  final String name;
  final String iconName;
  final DeckKeyType type;
  final String payload;

  DeckKey({
    required this.id,
    required this.name,
    required this.iconName,
    required this.type,
    required this.payload,
  });
}

class StreamDeckPage extends StatefulWidget {
  const StreamDeckPage({super.key});

  @override
  State<StreamDeckPage> createState() => _StreamDeckPageState();
}

class _StreamDeckPageState extends State<StreamDeckPage> {
  final SocketService _socketService = sl<SocketService>();
  List<DeckKey> _keys = [];
  bool _isLoading = true;
  bool _isEditMode = false;

  Offset? _dragStart;
  String? _activeGestureFeedback;
  IconData? _activeGestureIcon;
  Timer? _feedbackTimer;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _showFeedback(String message, IconData icon) {
    _feedbackTimer?.cancel();
    setState(() {
      _activeGestureFeedback = message;
      _activeGestureIcon = icon;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _activeGestureFeedback = null;
          _activeGestureIcon = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    
    // Force horizontal (landscape) orientation when entering the Stream Deck
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _loadAllKeys();

    // Listen to updates from server to automatically refresh
    _socketService.on('launcher:apps:updated', (_) => _loadAllKeys());
    _socketService.on('launcher:websites:updated', (_) => _loadAllKeys());
    _socketService.on('workspace:list:updated', (_) => _loadAllKeys());
  }

  @override
  void dispose() {
    _socketService.off('launcher:apps:updated');
    _socketService.off('launcher:websites:updated');
    _socketService.off('workspace:list:updated');
    _feedbackTimer?.cancel();
    _pageController.dispose();

    // Restore portrait and landscape support when exiting the Stream Deck
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  Future<void> _loadAllKeys() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final List<DeckKey> loadedKeys = [];

    // Load Apps
    final appsCompleter = Completer<void>();
    _socketService.emit('launcher:apps', null, ack: (response) {
      if (response is Map && response['success'] == true && response['apps'] is List) {
        for (var item in response['apps']) {
          loadedKeys.add(DeckKey(
            id: item['id'] ?? '',
            name: item['name'] ?? '',
            iconName: item['icon'] ?? 'rocket',
            type: DeckKeyType.app,
            payload: item['executablePath'] ?? '',
          ));
        }
      }
      appsCompleter.complete();
    });

    // Load Websites
    final websCompleter = Completer<void>();
    _socketService.emit('launcher:websites', null, ack: (response) {
      if (response is Map && response['success'] == true && response['websites'] is List) {
        for (var item in response['websites']) {
          loadedKeys.add(DeckKey(
            id: item['id'] ?? '',
            name: item['name'] ?? '',
            iconName: item['icon'] ?? 'globe',
            type: DeckKeyType.website,
            payload: item['url'] ?? '',
          ));
        }
      }
      websCompleter.complete();
    });

    // Load Workspaces
    final wsCompleter = Completer<void>();
    _socketService.emit('workspace:list', null, ack: (response) {
      if (response is Map && response['success'] == true && response['workspaces'] is List) {
        for (var item in response['workspaces']) {
          loadedKeys.add(DeckKey(
            id: item['id'] ?? '',
            name: item['name'] ?? '',
            iconName: item['icon'] ?? 'code',
            type: DeckKeyType.workspace,
            payload: item['description'] ?? '',
          ));
        }
      }
      wsCompleter.complete();
    });

    await Future.wait<void>([
      appsCompleter.future,
      websCompleter.future,
      wsCompleter.future,
    ]).timeout(const Duration(seconds: 4), onTimeout: () => []);

    if (mounted) {
      setState(() {
        _keys = loadedKeys;
        _isLoading = false;
      });
    }
  }

  void _executeKey(DeckKey key) {
    HapticFeedback.mediumImpact();
    String eventName = '';
    Map<String, dynamic> payload = {'id': key.id};

    switch (key.type) {
      case DeckKeyType.app:
        eventName = 'launcher:launch-app';
        break;
      case DeckKeyType.website:
        eventName = 'launcher:launch-website';
        break;
      case DeckKeyType.workspace:
        eventName = 'workspace:execute';
        break;
    }

    _socketService.emit(eventName, payload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Triggered: ${key.name}'),
        duration: const Duration(milliseconds: 800),
        backgroundColor: _getKeyColor(key.type).withOpacity(0.8),
      ),
    );
  }

  void _deleteKey(DeckKey key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: Text(
          'Delete "${key.name}"?',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this action from the deck?',
          style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              
              String deleteEvent = '';
              switch (key.type) {
                case DeckKeyType.app:
                  deleteEvent = 'launcher:delete-app';
                  break;
                case DeckKeyType.website:
                  deleteEvent = 'launcher:delete-website';
                  break;
                case DeckKeyType.workspace:
                  deleteEvent = 'workspace:delete';
                  break;
              }

              _socketService.emit(deleteEvent, {'id': key.id}, ack: (_) {
                _loadAllKeys();
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getKeyColor(DeckKeyType type) {
    switch (type) {
      case DeckKeyType.app:
        return const Color(0xFF6366F1); // Royal Indigo
      case DeckKeyType.website:
        return const Color(0xFFF59E0B); // Warm Amber Gold
      case DeckKeyType.workspace:
        return const Color(0xFF10B981); // Emerald Mint
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'code':
      case 'vscode':
        return Icons.code_rounded;
      case 'chrome':
      case 'website':
      case 'globe':
        return Icons.language_rounded;
      case 'github':
        return Icons.hub_rounded;
      case 'chatgpt':
      case 'ai':
        return Icons.psychology_rounded;
      case 'terminal':
      case 'cmd':
        return Icons.terminal_rounded;
      case 'calculator':
      case 'calc':
        return Icons.calculate_rounded;
      case 'youtube':
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'music':
      case 'spotify':
        return Icons.music_note_rounded;
      case 'folder':
      case 'explorer':
        return Icons.folder_rounded;
      case 'workspace':
      case 'flow':
        return Icons.workspaces_filled;
      case 'settings':
        return Icons.settings_rounded;
      default:
        return Icons.rocket_launch_rounded;
    }
  }

  BoxDecoration _getKeyCardDecoration(DeckKey key) {
    final name = key.name.toLowerCase();
    
    if (name.contains('youtube')) {
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      );
    } else if (name.contains('instagram')) {
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF9CE34),
            Color(0xFFEE2A7B),
            Color(0xFF6228D7),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(26),
      );
    } else if (name.contains('github')) {
      return BoxDecoration(
        color: const Color(0xFF181717),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      );
    } else if (name.contains('google')) {
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      );
    } else if (name.contains('chatgpt') || name.contains('ai') || name.contains('openai')) {
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF10A37F),
            Color(0xFF0F9B77),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(26),
      );
    } else if (name.contains('music') || name.contains('spotify')) {
      return BoxDecoration(
        color: const Color(0xFF1ED760),
        borderRadius: BorderRadius.circular(26),
      );
    } else if (name.contains('hotstar')) {
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF2563EB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      );
    }
    
    // Default System/App key inner background:
    // Slightly lighter/darker grey solid background
    return BoxDecoration(
      color: const Color(0xFF323238),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: Colors.white.withOpacity(0.04),
        width: 1.0,
      ),
    );
  }

  Widget _buildKeyIcon(DeckKey key) {
    final name = key.name.toLowerCase();
    String? brandIconUrl;
    if (name.contains('code') || name.contains('vs code') || name.contains('visual studio')) {
      brandIconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Visual_Studio_Code_1.35_icon.svg/128px-Visual_Studio_Code_1.35_icon.svg.png';
    } else if (name.contains('chrome') || name.contains('browser')) {
      brandIconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/Google_Chrome_icon_%28February_2022%29.svg/128px-Google_Chrome_icon_%28February_2022%29.svg.png';
    }

    if (brandIconUrl != null) {
      return Center(
        child: SizedBox(
          width: 90,
          height: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              brandIconUrl,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => Icon(
                _getIconData(key.iconName),
                color: Colors.white,
                size: 68,
              ),
            ),
          ),
        ),
      );
    }

    if (key.iconName.startsWith('data:image/')) {
      try {
        final base64Str = key.iconName.split(',')[1];
        final bytes = base64Decode(base64Str);
        return Center(
          child: SizedBox(
            width: 92,
            height: 92,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain, // Fit to container box cleanly
                filterQuality: FilterQuality.medium, // Sharper scaling
                isAntiAlias: true,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.image_rounded,
                    color: Colors.white,
                    size: 68,
                  ),
                ),
              ),
            ),
          ),
        );
      } catch (_) {}
    }

    if (key.type == DeckKeyType.website) {
      try {
        String url = key.payload;
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://$url';
        }
        final uri = Uri.parse(url);
        final domain = uri.host.isNotEmpty ? uri.host : key.payload;
        // Use the agent's favicon proxy to avoid CORS issues in Flutter web
        final agentBase = _socketService.agentBaseUrl ?? 'http://localhost:8081';
        final faviconUrl = '$agentBase/favicon?domain=${Uri.encodeComponent(domain)}&v=1.3';
        return Center(
          child: SizedBox(
            width: 90,
            height: 90,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                faviconUrl,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.language_rounded,
                  color: Colors.white,
                  size: 68,
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      } catch (_) {}
    }

    // Default icon from database/system
    IconData iconData = _getIconData(key.iconName);
    final lowerName = key.name.toLowerCase();
    if (lowerName.contains('lock') || key.iconName.toLowerCase().contains('lock')) {
      iconData = Icons.lock_outline_rounded;
    } else if (lowerName.contains('record') || lowerName.contains('dot')) {
      iconData = Icons.radio_button_checked_rounded;
    } else if (lowerName.contains('window') || lowerName.contains('screen')) {
      iconData = Icons.crop_portrait_rounded;
    }

    return Center(
      child: Icon(
        iconData,
        color: Colors.white,
        size: 68, // Large centered icon inside card
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayKeys = _keys.take(8).toList();
    // Only show add button if in edit mode and keys < 8
    final showAddButton = _isEditMode && displayKeys.length < 8;
    final itemCount = displayKeys.length + (showAddButton ? 1 : 0);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate aspect ratio dynamically so that the 4x2 grid fits perfectly in the available screen space.
    final availableHeight = screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 60;
    final availableWidth = screenWidth - 48; // padding 24 * 2

    // With 4 columns and 2 rows:
    double aspectRatio = (availableWidth / 2) / (availableHeight > 0 ? availableHeight : 1);
    
    // Clamp to a range that keeps the keycaps looking squarish but responsive
    if (aspectRatio < 0.8) aspectRatio = 0.8;
    if (aspectRatio > 1.4) aspectRatio = 1.4;

    return Scaffold(
      backgroundColor: const Color(0xFF080B11),
      body: Stack(
        children: [
          // Background Gradient
          Container(
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
          ),
          
          // Grid Content
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (page) {
                              setState(() {
                                _currentPage = page;
                              });
                            },
                            children: [
                              _buildShortcutsGrid(displayKeys, showAddButton, itemCount, aspectRatio),
                              _buildSystemControlsGrid(aspectRatio),
                              _buildEmptyGrid(aspectRatio),
                            ],
                          ),
                        ),
                        // Page indicators matching dynamic index
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                
          // Floating back and edit overlays
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => context.go('/dashboard'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _loadAllKeys,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEditMode = !_isEditMode;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isEditMode ? Icons.check_circle_rounded : Icons.edit_rounded,
                        color: _isEditMode ? Colors.greenAccent : Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gesture Feedback HUD overlay
          if (_activeGestureFeedback != null)
            Center(
              child: Container(
                width: 160,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _activeGestureIcon,
                          color: Colors.white,
                          size: 46,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _activeGestureFeedback!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShortcutsGrid(List<DeckKey> displayKeys, bool showAddButton, int itemCount, double aspectRatio) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showAddButton && index == displayKeys.length) {
          return _buildAddKeyButton();
        }
        return _buildStreamKey(displayKeys[index]);
      },
    );
  }

  Widget _buildSystemControlsGrid(double aspectRatio) {
    final List<Map<String, dynamic>> systemControls = [
      {
        'name': 'Volume Up',
        'icon': Icons.volume_up_rounded,
        'color': const Color(0xFF6366F1), // Royal Indigo
        'event': 'system:volume-up',
      },
      {
        'name': 'Volume Down',
        'icon': Icons.volume_down_rounded,
        'color': const Color(0xFF6366F1),
        'event': 'system:volume-down',
      },
      {
        'name': 'Toggle Silent',
        'icon': Icons.volume_off_rounded,
        'color': const Color(0xFFEF4444), // Crimson Red
        'event': 'system:volume-mute',
      },
      {
        'name': 'Brightness Up',
        'icon': Icons.brightness_high_rounded,
        'color': const Color(0xFFF59E0B), // Amber Gold
        'event': 'system:brightness-up',
      },
      {
        'name': 'Brightness Down',
        'icon': Icons.brightness_low_rounded,
        'color': const Color(0xFFF59E0B),
        'event': 'system:brightness-down',
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        if (index >= systemControls.length) {
          return _buildEmptyKeycap();
        }
        
        final ctrl = systemControls[index];
        return _buildSystemKeycap(
          name: ctrl['name'] as String,
          icon: ctrl['icon'] as IconData,
          color: ctrl['color'] as Color,
          event: ctrl['event'] as String,
        );
      },
    );
  }

  Widget _buildSystemKeycap({
    required String name,
    required IconData icon,
    required Color color,
    required String event,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _socketService.emit(event, null);
        _showFeedback(name, icon);
      },
      child: Container(
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1D23),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyKeycap() {
    return Container(
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF15171C),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.02),
          width: 1.0,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withOpacity(0.02),
            width: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGrid(double aspectRatio) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1D23),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white24, size: 24),
                  SizedBox(height: 6),
                  Text(
                    'Page 3',
                    style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildEmptyKeycap();
      },
    );
  }

  Widget _buildStreamKey(DeckKey key) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            if (_isEditMode) {
              _deleteKey(key);
            } else {
              _executeKey(key);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(6.0), // Spacing/margin around the inner card for bezel effect
            decoration: BoxDecoration(
              color: const Color(0xFF1B1D23), // Deep keycap bezel grey
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.04),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: _getKeyCardDecoration(key),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  children: [
                    // Center Icon (fills background if it's an image, or centers in card if standard icon)
                    Positioned.fill(
                      child: _buildKeyIcon(key),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Delete overlay in Edit Mode
        if (_isEditMode)
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: () => _deleteKey(key),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddKeyButton() {
    return GestureDetector(
      onTap: () => _showAddActionSheet(context),
      child: Container(
        padding: const EdgeInsets.all(6.0), // Spacing/margin around inner add key card
        decoration: BoxDecoration(
          color: const Color(0xFF1B1D23), // Deep keycap bezel grey
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D30).withOpacity(0.4),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.03),
              width: 1.0,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Colors.white38,
                  size: 28,
                ),
                SizedBox(height: 2),
                Text(
                  'Add Key',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UnifiedActionCreatorSheet(),
    ).then((_) => _loadAllKeys());
  }
}

class UnifiedActionCreatorSheet extends StatefulWidget {
  const UnifiedActionCreatorSheet({super.key});

  @override
  State<UnifiedActionCreatorSheet> createState() => _UnifiedActionCreatorSheetState();
}

class _UnifiedActionCreatorSheetState extends State<UnifiedActionCreatorSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocketService _socketService = sl<SocketService>();

  // Form controllers
  final _appNameController = TextEditingController();
  final _appPathController = TextEditingController();
  final _appCategoryController = TextEditingController(text: 'Utilities');

  final _webNameController = TextEditingController();
  final _webUrlController = TextEditingController();

  final _wsNameController = TextEditingController();
  final _wsDescController = TextEditingController();

  // Selected icon names
  String _selectedAppIcon = 'rocket';
  String _selectedWebIcon = 'globe';
  String _selectedWsIcon = 'code';

  // Workflow Builder Steps
  final List<Map<String, String>> _workflowSteps = [];

  final List<String> _iconOptions = [
    'rocket',
    'code',
    'chrome',
    'terminal',
    'calculator',
    'music',
    'folder',
    'github',
    'chatgpt',
    'youtube'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appNameController.dispose();
    _appPathController.dispose();
    _appCategoryController.dispose();
    _webNameController.dispose();
    _webUrlController.dispose();
    _wsNameController.dispose();
    _wsDescController.dispose();
    super.dispose();
  }

  void _saveApp() {
    if (_appNameController.text.trim().isEmpty || _appPathController.text.trim().isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    _socketService.emit('launcher:register-app', {
      'name': _appNameController.text.trim(),
      'executablePath': _appPathController.text.trim(),
      'icon': _selectedAppIcon,
      'category': _appCategoryController.text.trim(),
    }, ack: (res) {
      if (res is Map && res['success'] == true) {
        Navigator.pop(context);
      } else {
        _showError('Failed to save app');
      }
    });
  }

  void _saveWebsite() {
    if (_webNameController.text.trim().isEmpty || _webUrlController.text.trim().isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    String url = _webUrlController.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    _socketService.emit('launcher:register-website', {
      'name': _webNameController.text.trim(),
      'url': url,
      'icon': _selectedWebIcon,
    }, ack: (res) {
      if (res is Map && res['success'] == true) {
        Navigator.pop(context);
      } else {
        _showError('Failed to save website');
      }
    });
  }

  void _saveWorkspace() {
    if (_wsNameController.text.trim().isEmpty) {
      _showError('Please enter a name for the workflow');
      return;
    }

    final wsId = 'ws-${DateTime.now().millisecondsSinceEpoch}';
    final List<Map<String, dynamic>> actionsPayload = [];

    for (int i = 0; i < _workflowSteps.length; i++) {
      final step = _workflowSteps[i];
      actionsPayload.add({
        'actionType': step['type'],
        'payload': jsonEncode({
          if (step['type'] == 'run_command') 'command': step['value'],
          if (step['type'] == 'launch_website') 'url': step['value'],
        }),
        'sequenceOrder': i,
      });
    }

    _socketService.emit('workspace:register', {
      'id': wsId,
      'name': _wsNameController.text.trim(),
      'description': _wsDescController.text.trim(),
      'icon': _selectedWsIcon,
      'actions': actionsPayload,
    }, ack: (res) {
      if (res is Map && res['success'] == true) {
        Navigator.pop(context);
      } else {
        _showError('Failed to save workspace');
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _addWorkflowStepDialog() {
    final valController = TextEditingController();
    String actionType = 'run_command';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Text('Add Workflow Step', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: actionType,
                dropdownColor: AppTheme.surfaceColor,
                decoration: const InputDecoration(labelText: 'Action Type'),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'run_command', child: Text('Run Terminal Command')),
                  DropdownMenuItem(value: 'launch_website', child: Text('Open URL / Website')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => actionType = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: actionType == 'run_command' ? 'Terminal Command' : 'URL Link',
                  hintText: actionType == 'run_command' ? 'e.g. calc.exe or code' : 'e.g. https://github.com',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (valController.text.trim().isNotEmpty) {
                  setState(() {
                    _workflowSteps.add({
                      'type': actionType,
                      'value': valController.text.trim(),
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Dynamically calculate remaining height for tab contents
    double tabContentHeight = screenHeight - keyboardHeight - 140;
    if (tabContentHeight < 160) tabContentHeight = 160;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: keyboardHeight + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Create New Deck Action',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.zero,
            tabs: const [
              Tab(text: 'App', height: 36),
              Tab(text: 'Website', height: 36),
              Tab(text: 'Workflow', height: 36),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: tabContentHeight,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAppForm(),
                _buildWebsiteForm(),
                _buildWorkflowForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _appNameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'App Name',
              hintText: 'e.g. Visual Studio Code',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _appPathController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Executable Path / Alias',
              hintText: 'e.g. code or C:\\Program Files\\...',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select Button Icon', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          _buildIconSelector(_selectedAppIcon, (icon) => setState(() => _selectedAppIcon = icon)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveApp,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add App to Deck', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _webNameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Website Name',
              hintText: 'e.g. GitHub',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _webUrlController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'URL Link',
              hintText: 'e.g. github.com',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select Button Icon', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          _buildIconSelector(_selectedWebIcon, (icon) => setState(() => _selectedWebIcon = icon)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveWebsite,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.secondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Website to Deck', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _wsNameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Workflow Name',
            hintText: 'e.g. Morning Dev Routine',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Workflow Steps:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: _addWorkflowStepDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Step', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        Expanded(
          child: _workflowSteps.isEmpty
              ? Center(
                  child: Text(
                    'No steps added yet. Add tasks to run sequentially.',
                    style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 11),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _workflowSteps.length,
                  itemBuilder: (context, index) {
                    final step = _workflowSteps[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            step['type'] == 'run_command' ? Icons.terminal_rounded : Icons.language_rounded,
                            size: 16,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step['value'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 16),
                            onPressed: () {
                              setState(() {
                                _workflowSteps.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _saveWorkspace,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Colors.orangeAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Add Workflow to Deck', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
        ),
      ],
    );
  }

  Widget _buildIconSelector(String selectedIcon, Function(String) onSelect) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _iconOptions.length,
        itemBuilder: (context, index) {
          final iconName = _iconOptions[index];
          final isSelected = selectedIcon == iconName;
          return GestureDetector(
            onTap: () => onSelect(iconName),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Icon(
                _getIconData(iconName),
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                size: 20,
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'code':
        return Icons.code_rounded;
      case 'chrome':
        return Icons.language_rounded;
      case 'terminal':
        return Icons.terminal_rounded;
      case 'calculator':
        return Icons.calculate_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'folder':
        return Icons.folder_rounded;
      case 'github':
        return Icons.hub_rounded;
      case 'chatgpt':
        return Icons.psychology_rounded;
      case 'youtube':
        return Icons.play_circle_fill_rounded;
      default:
        return Icons.rocket_launch_rounded;
    }
  }
}


