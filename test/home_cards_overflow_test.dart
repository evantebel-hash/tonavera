import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/widgets/v35/v35_media_card.dart';

void main() {
  group('HomeScreen Media Cards Overflow & Responsive Tests', () {
    testWidgets('Recently Played tray (height 175, width 120) does not overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 175,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  V35MediaCard(
                    title: 'Short Title',
                    subtitle: 'Short Artist',
                    width: 120,
                    aspectRatio: 1.0,
                  ),
                  V35MediaCard(
                    title: 'Very Long Song Title That Will Truncate With Ellipsis On Home Screen',
                    subtitle: 'Very Long Artist Name That Also Truncates Gracefully',
                    width: 120,
                    aspectRatio: 1.0,
                  ),
                  V35MediaCard(
                    title: 'Title Without Subtitle',
                    width: 120,
                    aspectRatio: 1.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Popular Artists tray (height 155, width 100, isCircular) does not overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 155,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  V35MediaCard(
                    title: 'Tulus',
                    subtitle: 'Artis',
                    isCircular: true,
                    width: 100,
                    aspectRatio: 1.0,
                  ),
                  V35MediaCard(
                    title: 'Very Long Artist Name Overflow Truncation Test',
                    subtitle: 'Artis Populer Subtitle',
                    isCircular: true,
                    width: 100,
                    aspectRatio: 1.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Album Pilihan tray (height 195, width 140) does not overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 195,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  V35MediaCard(
                    title: 'Monokrom (Album Spesial)',
                    subtitle: 'Tulus • 2016',
                    width: 140,
                    aspectRatio: 1.0,
                  ),
                  V35MediaCard(
                    title: 'Super Long Album Title Designed To Test Single Line Clamping And Layout Integrity',
                    subtitle: 'Very Long Artist Name That Exceeds Width',
                    width: 140,
                    aspectRatio: 1.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive to multiple Windows screen resolutions', (WidgetTester tester) async {
      final resolutions = [
        const Size(800, 600),
        const Size(1024, 768),
        const Size(1366, 768),
        const Size(1920, 1080),
        const Size(2560, 1440),
      ];

      for (final size in resolutions) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recently Played
                        SizedBox(
                          height: 175,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 5,
                            itemBuilder: (context, i) => const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: V35MediaCard(
                                title: 'Recent Song Title',
                                subtitle: 'Recent Artist',
                                width: 120,
                                aspectRatio: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Album Pilihan
                        SizedBox(
                          height: 195,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 5,
                            itemBuilder: (context, i) => const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: V35MediaCard(
                                title: 'Album Title',
                                subtitle: 'Album Artist',
                                width: 140,
                                aspectRatio: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Artis Populer
                        SizedBox(
                          height: 155,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 5,
                            itemBuilder: (context, i) => const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: V35MediaCard(
                                title: 'Artist Name',
                                subtitle: 'Artis',
                                isCircular: true,
                                width: 100,
                                aspectRatio: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Failed at resolution $size');
      }

      // Reset test surface
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
