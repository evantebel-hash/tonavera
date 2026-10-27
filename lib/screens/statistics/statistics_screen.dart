import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/listening_statistics_model.dart';
import '../../providers/listening_statistics_provider.dart';
import '../../widgets/statistics/stat_metric_card.dart';
import '../../widgets/statistics/activity_bar_chart.dart';
import '../../widgets/statistics/listening_calendar_widget.dart';
import '../../widgets/statistics/top_music_section_widget.dart';
import '../../widgets/statistics/listening_history_list_widget.dart';

/// V3.5 Obsidian Emerald Statistics Screen.
///
/// Features:
/// - Overview telemetry cards with Emerald accents
/// - Top tracks, artists, and albums
/// - Heatmap calendar visualization
/// - Infinite listening history stream
/// - Full preservation of ListeningStatisticsProvider calculations and database queries.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ListeningStatisticsProvider>(
        context,
        listen: false,
      ).fetchAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsProv = Provider.of<ListeningStatisticsProvider>(context);

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        V35Tokens.space20,
                        V35Tokens.space16,
                        V35Tokens.space20,
                        V35Tokens.space8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Statistik Mendengarkan',
                                style: V35Tokens.display.copyWith(
                                  fontSize: 26.0,
                                  fontWeight: FontWeight.w700,
                                  color: V35Tokens.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  color: V35Tokens.accent,
                                  size: 22,
                                ),
                                tooltip: 'Perbarui Data',
                                splashRadius: 20,
                                onPressed: () => statsProv.fetchAll(),
                              ),
                            ],
                          ),
                          const SizedBox(height: V35Tokens.space12),

                          // Time Filter Bar
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: StatisticsTimeRange.values.map((range) {
                                final isSelected =
                                    statsProv.selectedTimeRange == range;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    right: V35Tokens.space8,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(range.label),
                                    selected: isSelected,
                                    selectedColor: V35Tokens.accent,
                                    backgroundColor: V35Tokens.bgSurface,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.black
                                          : V35Tokens.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 12.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: V35Tokens.brFull,
                                      side: BorderSide(
                                        color: isSelected
                                            ? V35Tokens.accent
                                            : V35Tokens.borderSubtle,
                                      ),
                                    ),
                                    onSelected: (_) =>
                                        statsProv.setTimeRange(range),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: V35Tokens.space12),

                          // Sub-tabs (Overview, Top Music, Calendar, History)
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            indicatorColor: V35Tokens.accent,
                            labelColor: V35Tokens.accent,
                            unselectedLabelColor: V35Tokens.textMuted,
                            labelStyle: V35Tokens.title.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                            unselectedLabelStyle: V35Tokens.secondary.copyWith(
                              fontSize: 13.5,
                            ),
                            dividerColor: V35Tokens.borderSubtle,
                            tabs: const [
                              Tab(text: 'Ringkasan'),
                              Tab(text: 'Musik Teratas'),
                              Tab(text: 'Kalender'),
                              Tab(text: 'Riwayat'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: statsProv.isLoading
                  ? Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: V35Tokens.accent,
                        ),
                      ),
                    )
                  : statsProv.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 44,
                          ),
                          const SizedBox(height: V35Tokens.space12),
                          Text(
                            'Gagal memuat statistik: ${statsProv.error}',
                            style: V35Tokens.body.copyWith(
                              color: V35Tokens.textMuted,
                            ),
                          ),
                          const SizedBox(height: V35Tokens.space16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: V35Tokens.accent,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () => statsProv.fetchAll(),
                            child: const Text(
                              'Coba Lagi',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(statsProv),
                        _buildTopMusicTab(statsProv),
                        _buildCalendarTab(statsProv),
                        _buildHistoryTab(statsProv),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  // --- OVERVIEW DASHBOARD ---
  Widget _buildOverviewTab(ListeningStatisticsProvider prov) {
    final stats = prov.statistics;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: V35Tokens.space20,
        vertical: V35Tokens.space12,
      ),
      children: [
        // Primary Highlight Card (Obsidian Emerald)
        Container(
          padding: const EdgeInsets.all(V35Tokens.space20),
          decoration: BoxDecoration(
            color: V35Tokens.bgSurface,
            borderRadius: V35Tokens.brLg,
            border: Border.all(
              color: V35Tokens.accent.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: V35Tokens.accent.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    color: V35Tokens.accent,
                    size: 22,
                  ),
                  const SizedBox(width: V35Tokens.space8),
                  Text(
                    'Total Waktu Mendengarkan',
                    style: V35Tokens.secondary.copyWith(
                      color: V35Tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: V35Tokens.space12),
              Text(
                _formatFullTime(stats.totalListeningTimeSeconds),
                style: V35Tokens.display.copyWith(
                  fontSize: 32.0,
                  fontWeight: FontWeight.w700,
                  color: V35Tokens.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${stats.totalPlays} putaran lagu • Rata-rata ${_formatMinutes(stats.averageDurationSeconds)} per lagu',
                style: V35Tokens.secondary.copyWith(
                  color: V35Tokens.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: V35Tokens.space16),

        // KPI Grid
        GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.5 : 1.3,
          children: [
            StatMetricCard(
              title: 'Lagu Diputar',
              value: '${stats.totalPlays}',
              subtitle: '${stats.uniqueSongs} lagu unik',
              icon: Icons.music_note_rounded,
              iconColor: V35Tokens.accent,
            ),
            StatMetricCard(
              title: 'Artis Unik',
              value: '${stats.uniqueArtists}',
              subtitle: 'Penjelajahan artis',
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF38BDF8),
            ),
            StatMetricCard(
              title: 'Album Unik',
              value: '${stats.uniqueAlbums}',
              subtitle: 'Koleksi album',
              icon: Icons.album_rounded,
              iconColor: const Color(0xFFFBBF24),
            ),
            StatMetricCard(
              title: 'Tingkat Selesai',
              value: '${stats.completionRate.toStringAsFixed(1)}%',
              subtitle:
                  '${stats.completedPlays} selesai, ${stats.skippedPlays} skip',
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFFEC4899),
            ),
          ],
        ),
        const SizedBox(height: V35Tokens.space20),

        // Activity Bar Chart
        ActivityBarChart(
          monthlyActivity: prov.monthlyActivity,
          year: prov.calendarYear,
          month: prov.calendarMonth,
        ),
        const SizedBox(height: V35Tokens.space24),
      ],
    );
  }

  // --- TOP MUSIC TAB ---
  Widget _buildTopMusicTab(ListeningStatisticsProvider prov) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: V35Tokens.space20,
        vertical: V35Tokens.space12,
      ),
      children: [
        TopMusicSectionWidget(
          topSongs: prov.topSongs,
          topArtists: prov.topArtists,
          topAlbums: prov.topAlbums,
        ),
        const SizedBox(height: V35Tokens.space24),
      ],
    );
  }

  // --- CALENDAR TAB ---
  Widget _buildCalendarTab(ListeningStatisticsProvider prov) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: V35Tokens.space20,
        vertical: V35Tokens.space12,
      ),
      children: [
        ListeningCalendarWidget(
          year: prov.calendarYear,
          month: prov.calendarMonth,
          monthlyActivity: prov.monthlyActivity,
          selectedDate: prov.selectedDate,
          selectedDateHistory: prov.selectedDateHistory,
          onMonthChanged: (y, m) => prov.changeCalendarMonth(y, m),
          onDateSelected: (date) => prov.selectCalendarDate(date),
        ),
        const SizedBox(height: V35Tokens.space24),
      ],
    );
  }

  // --- LISTENING HISTORY TAB ---
  Widget _buildHistoryTab(ListeningStatisticsProvider prov) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: V35Tokens.space20,
        vertical: V35Tokens.space12,
      ),
      children: [
        ListeningHistoryListWidget(
          history: prov.historyStream,
          hasMore: prov.hasMoreHistory,
          isLoadingMore: prov.isLoadingMoreHistory,
          onLoadMore: () => prov.loadMoreHistory(),
          onClearHistory: () => _confirmClearHistory(context, prov),
        ),
        const SizedBox(height: V35Tokens.space24),
      ],
    );
  }

  Future<void> _confirmClearHistory(
    BuildContext context,
    ListeningStatisticsProvider prov,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V35Tokens.bgElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: V35Tokens.brLg,
          side: BorderSide(color: V35Tokens.borderSubtle),
        ),
        title: Text(
          'Hapus Riwayat Mendengarkan?',
          style: V35Tokens.title.copyWith(
            color: V35Tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Semua data riwayat pemutaran lokal akan dihapus. Lagu, playlist, dan favorit Anda tidak akan terpengaruh.',
          style: V35Tokens.secondary.copyWith(color: V35Tokens.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: V35Tokens.mono.copyWith(color: V35Tokens.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: V35Tokens.brSm),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await prov.clearAllHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Riwayat pemutaran berhasil dibersihkan.'),
            backgroundColor: V35Tokens.success,
          ),
        );
      }
    }
  }

  String _formatFullTime(int seconds) {
    if (seconds < 60) return '$seconds detik';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours == 0) return '$mins menit';
    return '$hours jam $mins menit';
  }

  String _formatMinutes(int seconds) {
    final mins = seconds ~/ 60;
    final rem = seconds % 60;
    return '${mins}m ${rem}s';
  }
}
