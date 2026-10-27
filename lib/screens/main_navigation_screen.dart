import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/v35_tokens.dart';
import '../core/theme/v35_accent.dart';
import '../widgets/v35/v35_sidebar_item.dart';
import '../widgets/v35/v35_queue_panel.dart';
import '../widgets/mini_player.dart';
import '../services/desktop/desktop_integration_service.dart';
import '../services/music_import_service.dart';
import '../services/notification_permission_service.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
import 'library/library_screen.dart';
import 'statistics/statistics_screen.dart';
import 'profile/profile_screen.dart';
import 'player/player_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/player_provider.dart';
import '../providers/catalog_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isMiniPlayerMode = false;
  bool _isDraggingFiles = false;
  bool _isQueuePanelOpen = false;
  @override
  void initState() {
    super.initState();
    V35Accent.notifier.addListener(_onAccentChanged);
    _isMiniPlayerMode = DesktopIntegrationService.instance.isMiniPlayerMode;
    DesktopIntegrationService.instance.miniPlayerNotifier.addListener(
      _onMiniPlayerModeChanged,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final player = Provider.of<PlayerProvider>(context, listen: false);

        await DesktopIntegrationService.instance.init(playerProvider: player);
        DesktopIntegrationService.instance.setToggleMiniPlayerCallback(
          _toggleMiniPlayerMode,
        );
        DesktopIntegrationService.instance.setFilesDroppedCallback(
          _handleFilesDropped,
        );
        DesktopIntegrationService.instance.setOpenQueueCallback(() {
          if (mounted) {
            setState(() => _isQueuePanelOpen = true);
          }
        });
        DesktopIntegrationService.instance.setOpenFullPlayerCallback(() {
          if (mounted) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
          }
        });

        if (mounted && auth.isAuthenticated) {
          await Provider.of<HistoryProvider>(
            context,
            listen: false,
          ).fetchRecentlyPlayed();
        }

        if (Platform.isAndroid) {
          NotificationPermissionService.requestPermissionIfNeeded();
        }
      } catch (e) {
        debugPrint('MainNavigationScreen: Init warning: $e');
      }
    });
  }

  void _onMiniPlayerModeChanged() {
    if (mounted) {
      setState(() {
        _isMiniPlayerMode =
            DesktopIntegrationService.instance.miniPlayerNotifier.value;
      });
    }
  }

  void _onAccentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    V35Accent.notifier.removeListener(_onAccentChanged);
    DesktopIntegrationService.instance.miniPlayerNotifier.removeListener(
      _onMiniPlayerModeChanged,
    );
    DesktopIntegrationService.instance.setOpenQueueCallback(null);
    DesktopIntegrationService.instance.setOpenFullPlayerCallback(null);
    super.dispose();
  }

  void _toggleMiniPlayerMode() {
    setState(() {
      _isMiniPlayerMode = DesktopIntegrationService.instance.isMiniPlayerMode;
    });
  }

  Future<void> _handleFilesDropped(List<String> paths) async {
    if (paths.isEmpty) return;

    setState(() => _isDraggingFiles = true);

    try {
      final importService = MusicImportService();
      final summary = await importService.importPaths(paths: paths);

      if (mounted) {
        // Refresh catalog & player
        Provider.of<CatalogProvider>(context, listen: false).fetchCatalogData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impor Selesai: ${summary.importedCount} lagu baru ditambahkan (${summary.skippedDuplicates} duplikat dilewati).',
            ),
            backgroundColor: summary.importedCount > 0
                ? AppColors.primary
                : Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses file yang di-drop: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDraggingFiles = false);
      }
    }
  }

  List<Widget> get _screens => [
    const HomeScreen(),
    const SearchScreen(),
    const LibraryScreen(),
    const StatisticsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    V35Accent.onSongChanged(player.currentSong);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= V35Tokens.tabletBreakPoint;

    Widget mainContent;

    if (isDesktop) {
      // Desktop / Tablet Sidebar Layout with Bottom Player Bar
      mainContent = Scaffold(
        backgroundColor: V35Tokens.bgVoid,
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // V3.5 Desktop Sidebar Navigation (240px)
                  Container(
                    width: V35Tokens.desktopSidebarWidth,
                    decoration: const BoxDecoration(
                      color: V35Tokens.bgSurface,
                      border: Border(
                        right: BorderSide(
                          color: V35Tokens.borderSubtle,
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Brand Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: V35Tokens.space20,
                            horizontal: V35Tokens.space16,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: V35Tokens.accent.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: V35Tokens.brMd,
                                  border: Border.all(
                                    color: V35Tokens.accent.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/tonavera_symbol_white.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(width: V35Tokens.space12),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      'TONAVERA',
                                      style: V35Tokens.heading.copyWith(
                                        fontSize: 18,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: V35Tokens.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!kIsWeb && Platform.isWindows)
                                IconButton(
                                  icon: const Icon(
                                    Icons.picture_in_picture_alt_rounded,
                                    size: 18,
                                  ),
                                  color: _isMiniPlayerMode
                                      ? V35Tokens.accent
                                      : V35Tokens.textSecondary,
                                  tooltip: _isMiniPlayerMode
                                      ? 'Sembunyikan Mini Player Melayang'
                                      : 'Buka Mini Player Melayang',
                                  onPressed: () {
                                    DesktopIntegrationService.instance
                                        .setMiniPlayerMode(!_isMiniPlayerMode);
                                  },
                                ),
                            ],
                          ),
                        ),
                        const Divider(color: V35Tokens.borderSubtle, height: 1),
                        const SizedBox(height: V35Tokens.space8),

                        // Navigation Destinations (Existing routes preserved)
                        V35SidebarItem(
                          icon: Icons.home_rounded,
                          label: 'Home',
                          isSelected: _selectedIndex == 0,
                          onTap: () => setState(() => _selectedIndex = 0),
                        ),
                        V35SidebarItem(
                          icon: Icons.search_rounded,
                          label: 'Search',
                          isSelected: _selectedIndex == 1,
                          onTap: () => setState(() => _selectedIndex = 1),
                        ),
                        V35SidebarItem(
                          icon: Icons.library_music_rounded,
                          label: 'Library',
                          isSelected: _selectedIndex == 2,
                          onTap: () => setState(() => _selectedIndex = 2),
                        ),
                        V35SidebarItem(
                          icon: Icons.bar_chart_rounded,
                          label: 'Statistics',
                          isSelected: _selectedIndex == 3,
                          onTap: () => setState(() => _selectedIndex = 3),
                        ),
                        V35SidebarItem(
                          icon: Icons.person_rounded,
                          label: 'Profile',
                          isSelected: _selectedIndex == 4,
                          onTap: () => setState(() => _selectedIndex = 4),
                        ),
                      ],
                    ),
                  ),

                  // Main Content Area (Obsidian Base background)
                  Expanded(
                    child: Container(
                      color: V35Tokens.bgBase,
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: _screens,
                      ),
                    ),
                  ),

                  // Contextual Right-Side Queue Panel (Desktop, 320px)
                  if (_isQueuePanelOpen)
                    SizedBox(
                      width: V35Tokens.desktopQueuePanelWidth,
                      child: V35QueuePanel(
                        onClose: () =>
                            setState(() => _isQueuePanelOpen = false),
                      ),
                    ),
                ],
              ),
            ),
            // Persistent Mini Player with Desktop Queue Toggle
            MiniPlayer(
              onQueueTap: () {
                setState(() => _isQueuePanelOpen = !_isQueuePanelOpen);
              },
              isQueueOpen: _isQueuePanelOpen,
            ),
          ],
        ),
      );
    } else {
      // Mobile Layout with MiniPlayer above Bottom Navigation
      mainContent = Scaffold(
        backgroundColor: V35Tokens.bgBase,
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Persistent Mini Player (Phase 3A: preserved untouched)
            const MiniPlayer(),
            Container(
              decoration: const BoxDecoration(
                color: V35Tokens.bgSurface,
                border: Border(
                  top: BorderSide(color: V35Tokens.borderSubtle, width: 1.0),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _selectedIndex,
                    onTap: (index) => setState(() => _selectedIndex = index),
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: V35Tokens.bgSurface,
                    elevation: 0,
                    selectedItemColor: V35Tokens.accent,
                    unselectedItemColor: V35Tokens.textMuted,
                    selectedFontSize: 11.0,
                    unselectedFontSize: 11.0,
                    selectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                    showUnselectedLabels: true,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.search_rounded),
                        label: 'Search',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.library_music_rounded),
                        label: 'Library',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.bar_chart_rounded),
                        label: 'Stats',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_rounded),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Drag overlay for Windows file drops (restyled to V3.5 Obsidian Emerald)
    if (_isDraggingFiles) {
      mainContent = Stack(
        children: [
          mainContent,
          Container(
            color: V35Tokens.bgVoid.withValues(alpha: 0.8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(V35Tokens.space32),
                decoration: BoxDecoration(
                  color: V35Tokens.bgElevated,
                  borderRadius: V35Tokens.brXl,
                  border: Border.all(color: V35Tokens.accent, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: V35Tokens.accent.withValues(alpha: 0.25),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        V35Tokens.accent,
                      ),
                    ),
                    const SizedBox(height: V35Tokens.space20),
                    Text(
                      'Sedang Mengimpor Musik...',
                      style: V35Tokens.heading.copyWith(
                        fontSize: 18,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return mainContent;
  }
}
