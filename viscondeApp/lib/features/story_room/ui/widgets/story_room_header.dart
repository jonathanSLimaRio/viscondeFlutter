import 'package:flutter/material.dart';
import '../../../../design_system/visconde.dart';

class StoryRoomHeader extends StatelessWidget {
  const StoryRoomHeader({
    super.key,
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    required this.xp,
    required this.maxXp,
    required this.themeArtKey,
  });

  final String title;
  final int currentStep;
  final int totalSteps;
  final int xp;
  final int maxXp;
  final ViscondeArtKey themeArtKey;

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
                  image: AssetImage(ViscondeArtRegistry.resolve(themeArtKey)),
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
                        title,
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
                  'Cena $currentStep/$totalSteps',
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
                flex: currentStep,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(radii.md),
                      bottomRight: currentStep == totalSteps
                          ? Radius.circular(radii.md)
                          : Radius.zero,
                    ),
                  ),
                ),
              ),
              Expanded(flex: totalSteps - currentStep, child: const SizedBox()),
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
                'XP  $xp / $maxXp',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Text('|'),
              const Spacer(),
              Text(
                'Etapa $currentStep',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.error_outline, color: Colors.redAccent),
            ],
          ),
        ),
      ],
    );
  }
}
