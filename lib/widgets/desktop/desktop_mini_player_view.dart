import 'package:flutter/material.dart';
import 'floating_mini_player.dart';

export 'floating_mini_player.dart';

/// Desktop Mini Player Window View wrapper.
/// Centers and renders the [FloatingMiniPlayer] within a transparent or themed canvas.
class DesktopMiniPlayerView extends StatelessWidget {
  final VoidCallback onExpandToFull;

  const DesktopMiniPlayerView({super.key, required this.onExpandToFull});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: FloatingMiniPlayer(onClose: onExpandToFull)),
    );
  }
}
