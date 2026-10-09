import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/socket_service.dart';
import '../../data/models/launcher_models.dart';
import '../bloc/launcher_bloc.dart';
import '../bloc/launcher_event.dart';
import '../bloc/launcher_state.dart';

class AppsLauncherPage extends StatefulWidget {
  const AppsLauncherPage({super.key});

  @override
  State<AppsLauncherPage> createState() => _AppsLauncherPageState();
}

class _AppsLauncherPageState extends State<AppsLauncherPage> {
  @override
  void initState() {
    super.initState();
    
    // Force horizontal (landscape) orientation on entry
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    context.read<LauncherBloc>().add(LauncherLoadApps());
  }

  @override
  void dispose() {
    // Restore default orientation on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'terminal': return Icons.terminal_rounded;
      case 'description': return Icons.description_rounded;
      case 'code': return Icons.code_rounded;
      case 'language': return Icons.language_rounded;
      case 'calculate': return Icons.calculate_rounded;
      case 'assessment': return Icons.assessment_rounded;
      case 'gamepad': return Icons.gamepad_rounded;
      case 'work': return Icons.work_rounded;
      default: return Icons.rocket_launch_rounded;
    }
  }

  Widget _buildAppIcon(AppModel app) {
    if (app.icon != null && app.icon!.startsWith('data:image/')) {
      try {
        final base64Str = app.icon!.split(',')[1];
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            bytes,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              _getIconData(app.icon),
              color: Colors.white,
              size: 44,
            ),
          ),
        );
      } catch (_) {}
    }

    final name = app.name.toLowerCase();
    String? brandIconUrl;
    if (name.contains('code') || name.contains('vs code') || name.contains('visual studio')) {
      brandIconUrl = 'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/vscode/vscode-original.svg';
    } else if (name.contains('chrome') || name.contains('browser')) {
      brandIconUrl = 'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/chrome/chrome-original.svg';
    } else if (name.contains('github')) {
      brandIconUrl = 'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/github/github-original.svg';
    } else if (name.contains('terminal') || name.contains('bash') || name.contains('cmd') || name.contains('powershell')) {
      brandIconUrl = 'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/bash/bash-original.svg';
    }

    if (brandIconUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          brandIconUrl,
          width: 44,
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            _getIconData(app.icon),
            color: Colors.white,
            size: 44,
          ),
        ),
      );
    }

    return Icon(
      _getIconData(app.icon),
      color: Colors.white,
      size: 44,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Quick App Launcher'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
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
        child: BlocConsumer<LauncherBloc, LauncherState>(
          listener: (context, state) {
            if (state is LauncherFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is LauncherLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              );
            } else if (state is LauncherAppsLoaded) {
              final apps = state.apps;
              return _buildContent(apps);
            } else if (state is LauncherFailure) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load apps',
                      style: TextStyle(fontSize: 18, color: AppTheme.textPrimary.withOpacity(0.9), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => context.read<LauncherBloc>().add(LauncherLoadApps()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(List<AppModel> apps) {
    final displayApps = apps.take(8).toList();
    final showAddButton = displayApps.length < 8;
    final itemCount = displayApps.length + (showAddButton ? 1 : 0);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - kToolbarHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 70;
    final availableWidth = screenWidth - 32;

    double aspectRatio = (availableWidth / 2) / (availableHeight > 0 ? availableHeight : 1);
    if (aspectRatio < 0.75) aspectRatio = 0.75;
    if (aspectRatio > 2.2) aspectRatio = 2.2;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tap to trigger, hold to delete. Max 8 apps.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, // 4 columns (4x2 layout)
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (showAddButton && index == displayApps.length) {
                    return _buildAddKeyButton();
                  }
                  return _buildAppKey(displayApps[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppKey(AppModel app) {
    final accentColor = const Color(0xFF6366F1); // Royal Indigo
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.read<LauncherBloc>().add(LauncherLaunchApp(app.id));
          },
          onLongPress: () => _showDeleteConfirmation(app),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.04),
                  accentColor.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 5,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 2,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.5),
                            blurRadius: 2,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: _buildAppIcon(app),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddKeyButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: GestureDetector(
          onTap: () => _showAddAppDialog(context),
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
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Colors.white38,
                  size: 28,
                ),
                SizedBox(height: 6),
                Text(
                  'Add Key',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
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

  void _showDeleteConfirmation(AppModel app) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Shortcut?'),
        content: Text('Are you sure you want to remove the shortcut for ${app.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<LauncherBloc>().add(LauncherDeleteApp(app.id));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAddAppDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => SystemAppDiscoveryDialog(
        socketService: context.read<LauncherBloc>().socketService,
        launcherBloc: context.read<LauncherBloc>(),
      ),
    );
  }
}

class SystemAppDiscoveryDialog extends StatefulWidget {
  final SocketService socketService;
  final LauncherBloc launcherBloc;

  const SystemAppDiscoveryDialog({
    super.key,
    required this.socketService,
    required this.launcherBloc,
  });

  @override
  State<SystemAppDiscoveryDialog> createState() => _SystemAppDiscoveryDialogState();
}

class _SystemAppDiscoveryDialogState extends State<SystemAppDiscoveryDialog> {
  bool _isLoading = true;
  String _searchQuery = '';
  List<dynamic> _runningApps = [];
  List<dynamic> _installedApps = [];
  String _activeTab = 'running'; // 'running', 'installed', 'manual'

  // Manual form controllers
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  String _selectedCategory = 'Utility';
  String _selectedIcon = 'rocket';

  @override
  void initState() {
    super.initState();
    _fetchSystemApps();
  }

  void _fetchSystemApps() {
    widget.socketService.emit('launcher:scan-system-apps', null, ack: (response) {
      if (mounted) {
        if (response is Map && response['success'] == true) {
          setState(() {
            _runningApps = response['running'] ?? [];
            _installedApps = response['installed'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  void _registerRunningApp(Map<String, dynamic> app) {
    widget.launcherBloc.add(LauncherAddApp(
      name: app['name'] ?? 'Unknown App',
      executablePath: app['executablePath'] ?? '',
      icon: app['icon'] ?? 'rocket',
      category: 'Utility',
    ));
    Navigator.pop(context);
  }

  void _registerInstalledApp(Map<String, dynamic> app) {
    setState(() {
      _isLoading = true;
    });
    // Extract icon first on demand
    widget.socketService.emit('launcher:extract-discovered-icon', {'path': app['executablePath']}, ack: (iconRes) {
      String iconStr = 'rocket';
      if (iconRes is Map && iconRes['success'] == true && iconRes['icon'] != null) {
        iconStr = iconRes['icon'];
      }
      widget.launcherBloc.add(LauncherAddApp(
        name: app['name'] ?? 'Unknown App',
        executablePath: app['executablePath'] ?? '',
        icon: iconStr,
        category: 'Utility',
      ));
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Widget _buildDiscoveredIcon(String? base64Icon) {
    if (base64Icon != null && base64Icon.startsWith('data:image/')) {
      try {
        final base64Str = base64Icon.split(',')[1];
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            bytes,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
        );
      } catch (_) {}
    }
    return const Icon(Icons.rocket_launch_rounded, color: Colors.blueAccent, size: 24);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    final height = MediaQuery.of(context).size.height * 0.85;

    // Filter lists based on search query
    final filteredRunning = _runningApps.where((app) {
      final name = (app['name'] ?? '').toString().toLowerCase();
      final path = (app['executablePath'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || path.contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredInstalled = _installedApps.where((app) {
      final name = (app['name'] ?? '').toString().toLowerCase();
      final path = (app['executablePath'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || path.contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: const Color(0xFF0F1015),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.blueAccent.withOpacity(0.2), width: 1.5),
      ),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFF2979FF)],
                  ).createShader(bounds),
                  child: const Text(
                    'ADD SHORTCUT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                if (_activeTab != 'manual')
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Search applications...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          icon: Icon(Icons.search_rounded, size: 16, color: Colors.white38),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Body
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sidebar navigation
                  Container(
                    width: 130,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSidebarTab(
                          id: 'running',
                          label: 'Active Now',
                          icon: Icons.play_arrow_rounded,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(height: 8),
                        _buildSidebarTab(
                          id: 'installed',
                          label: 'Installed',
                          icon: Icons.apps_rounded,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(height: 8),
                        _buildSidebarTab(
                          id: 'manual',
                          label: 'Manual Add',
                          icon: Icons.edit_rounded,
                          color: Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(color: Colors.white12, width: 24),
                  // Content area
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                            ),
                          )
                        : _buildTabContent(filteredRunning, filteredInstalled),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarTab({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _activeTab == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.white38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.white60,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<dynamic> running, List<dynamic> installed) {
    if (_activeTab == 'running') {
      if (running.isEmpty) {
        return const Center(
          child: Text(
            'No active apps with windows detected.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        );
      }
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: running.length,
        itemBuilder: (context, idx) {
          final app = running[idx];
          return _buildAppItem(
            name: app['name'] ?? '',
            path: app['executablePath'] ?? '',
            icon: _buildDiscoveredIcon(app['icon']),
            onTap: () => _registerRunningApp(Map<String, dynamic>.from(app)),
          );
        },
      );
    } else if (_activeTab == 'installed') {
      if (installed.isEmpty) {
        return const Center(
          child: Text(
            'No matching installed apps found.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        );
      }
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: installed.length,
        itemBuilder: (context, idx) {
          final app = installed[idx];
          return _buildAppItem(
            name: app['name'] ?? '',
            path: app['executablePath'] ?? '',
            icon: const Icon(Icons.rocket_launch_rounded, color: Colors.blueAccent, size: 24),
            onTap: () => _registerInstalledApp(Map<String, dynamic>.from(app)),
          );
        },
      );
    } else {
      // Manual registration form
      final icons = [
        {'label': 'Rocket', 'value': 'rocket'},
        {'label': 'Terminal', 'value': 'terminal'},
        {'label': 'Document', 'value': 'description'},
        {'label': 'Code', 'value': 'code'},
        {'label': 'Globe', 'value': 'language'},
        {'label': 'Calculator', 'value': 'calculate'},
        {'label': 'Chart', 'value': 'assessment'},
        {'label': 'Gamepad', 'value': 'gamepad'},
        {'label': 'Work', 'value': 'work'},
      ];

      final categories = ['Utility', 'Developer', 'System', 'Game', 'Social', 'Other'];

      return SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'App Name',
                labelStyle: TextStyle(color: Colors.white38),
                hintText: 'e.g. VS Code',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pathController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Executable Path / Command',
                labelStyle: TextStyle(color: Colors.white38),
                hintText: 'e.g. code or notepad.exe',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: const Color(0xFF0F1015),
              decoration: const InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
              ),
              items: categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedIcon,
              dropdownColor: const Color(0xFF0F1015),
              decoration: const InputDecoration(
                labelText: 'Icon Template',
                labelStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
              ),
              items: icons.map((icon) {
                return DropdownMenuItem(
                  value: icon['value'],
                  child: Text(icon['label']!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedIcon = val;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (_nameController.text.isNotEmpty && _pathController.text.isNotEmpty) {
                      widget.launcherBloc.add(LauncherAddApp(
                        name: _nameController.text,
                        executablePath: _pathController.text,
                        icon: _selectedIcon,
                        category: _selectedCategory,
                      ));
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add Shortcut', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAppItem({
    required String name,
    required String path,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: icon,
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
        trailing: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 20),
        onTap: onTap,
      ),
    );
  }
}
