import 'package:flutter/material.dart';

import 'visconde_glass_card.dart';
import 'visconde_mascot.dart';
import 'visconde_primary_cta.dart';
import 'visconde_section_title.dart';
import 'visconde_skeleton.dart';

enum ViscondeContentStateKind { loading, empty, error }

class ViscondeContentState extends StatelessWidget {
  const ViscondeContentState({
    super.key,
    required this.kind,
    required this.title,
    required this.description,
    this.icon,
    this.showMascot = false,
    this.mascotPose = ViscondeMascotPose.wavingControllerBook,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.leading,
  });

  const ViscondeContentState.loading({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.showMascot = true,
    this.mascotPose = ViscondeMascotPose.wavingControllerBook,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.leading,
  }) : kind = ViscondeContentStateKind.loading;

  const ViscondeContentState.empty({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.showMascot = true,
    this.mascotPose = ViscondeMascotPose.readingBook,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.leading,
  }) : kind = ViscondeContentStateKind.empty;

  const ViscondeContentState.error({
    super.key,
    required this.title,
    required this.description,
    this.icon = const Icon(Icons.error_outline_rounded),
    this.showMascot = false,
    this.mascotPose = ViscondeMascotPose.wavingControllerBook,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.leading,
  }) : kind = ViscondeContentStateKind.error;

  final ViscondeContentStateKind kind;
  final String title;
  final String description;
  final Widget? icon;
  final bool showMascot;
  final ViscondeMascotPose mascotPose;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ] else if (icon != null) ...[
                IconTheme(
                  data: IconThemeData(color: colors.primary, size: 24),
                  child: icon!,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ViscondeSectionTitle(
                  title: title,
                  subtitle: description,
                ),
              ),
              if (showMascot)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ViscondeMascot(
                    pose: mascotPose,
                    size: 72,
                    fit: BoxFit.contain,
                  ),
                ),
            ],
          ),
          if (kind == ViscondeContentStateKind.loading) ...[
            const SizedBox(height: 10),
            const ViscondeSkeletonBox(height: 12),
            const SizedBox(height: 8),
            const ViscondeSkeletonBox(height: 12, width: 220),
          ],
          if (primaryActionLabel != null || secondaryActionLabel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (primaryActionLabel != null) ...[
                  Expanded(
                    child: ViscondePrimaryCta(
                      onPressed: onPrimaryAction,
                      label: primaryActionLabel!,
                      icon: kind == ViscondeContentStateKind.error
                          ? Icons.refresh_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
                if (secondaryActionLabel != null) ...[
                  if (primaryActionLabel != null) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondaryAction,
                      child: Text(secondaryActionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
