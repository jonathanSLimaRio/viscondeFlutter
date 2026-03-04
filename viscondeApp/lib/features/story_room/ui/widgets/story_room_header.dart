import 'package:flutter/material.dart';
import '../../../../design_system/visconde.dart';

class StoryRoomHeader extends StatefulWidget {
  const StoryRoomHeader({
    super.key,
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    required this.xp,
    required this.maxXp,
    required this.themeArtKey,
    this.xpAnimationNonce = 0,
  });

  final String title;
  final int currentStep;
  final int totalSteps;
  final int xp;
  final int maxXp;
  final ViscondeArtKey themeArtKey;
  final int xpAnimationNonce;

  @override
  State<StoryRoomHeader> createState() => _StoryRoomHeaderState();
}

class _StoryRoomHeaderState extends State<StoryRoomHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _trophyController;
  bool _showTrophy = false;

  @override
  void initState() {
    super.initState();
    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
  }

  @override
  void didUpdateWidget(covariant StoryRoomHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.xpAnimationNonce != oldWidget.xpAnimationNonce) {
      _playTrophyAnimation();
    }
  }

  Future<void> _playTrophyAnimation() async {
    if (!_showTrophy && mounted) {
      setState(() => _showTrophy = true);
    }
    _trophyController.stop();
    _trophyController.value = 0;
    await _trophyController.forward();
    if (!mounted) {
      return;
    }
    await _trophyController.reverse();
    if (!mounted) {
      return;
    }
    setState(() => _showTrophy = false);
  }

  @override
  void dispose() {
    _trophyController.dispose();
    super.dispose();
  }

  Widget _buildTrophyAnimation() {
    if (!_showTrophy) {
      return const SizedBox(width: 20, height: 20);
    }
    return AnimatedBuilder(
      animation: _trophyController,
      builder: (context, child) {
        final value = _trophyController.value;
        if (value <= 0.01) {
          return const SizedBox(width: 20, height: 20);
        }

        final scale = 0.78 + (Curves.easeOutBack.transform(value) * 0.36);
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: const Icon(
        Icons.emoji_events_rounded,
        key: ValueKey<String>('story_room_xp_trophy'),
        color: Color(0xFFFFC107),
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radii = context.viscondeRadii;

    return Column(
      children: [
        // Top Banner with Title and Image
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(radii.md),
                  topRight: Radius.circular(radii.md),
                ),
                image: DecorationImage(
                  image: AssetImage(
                    ViscondeArtRegistry.resolve(widget.themeArtKey),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Title Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: radii.radius(radii.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(
                      Icons.picture_in_picture_alt,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            // Mascot
            Positioned(
              left: 0,
              bottom: 10,
              child: ViscondeMascot(
                pose: ViscondeMascotPose.readingBook,
                size: 100,
              ),
            ),
            // Scene count badge
            Positioned(
              right: 16,
              bottom: -16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F5B6F), // Darker teal matches UI
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cena ${widget.currentStep}/${widget.totalSteps}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Progress Bar attached to the bottom of the image
        Container(
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF1F5B6F), // Match badge color or background
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(radii.md),
              bottomRight: Radius.circular(radii.md),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: widget.currentStep,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(radii.md),
                      bottomRight: widget.currentStep == widget.totalSteps
                          ? Radius.circular(radii.md)
                          : Radius.zero,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: widget.totalSteps - widget.currentStep,
                child: const SizedBox(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // XP Bar & Level
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(Icons.local_florist, color: Colors.amber.shade600),
              const SizedBox(width: 8),
              Text(
                'XP  ${widget.xp} / ${widget.maxXp}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Etapa ${widget.currentStep}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              _buildTrophyAnimation(),
            ],
          ),
        ),
      ],
    );
  }
}
