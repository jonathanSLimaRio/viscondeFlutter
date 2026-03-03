import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParentalGateState {
  const ParentalGateState({this.unlockToken, this.expiresAt});

  final String? unlockToken;
  final DateTime? expiresAt;

  static const expirySafetyBuffer = Duration(seconds: 30);

  bool get isUnlocked {
    return isUnlockedAt(DateTime.now());
  }

  bool isUnlockedAt(DateTime now, {Duration expiryBuffer = Duration.zero}) {
    if (unlockToken == null || expiresAt == null) {
      return false;
    }

    final safeExpiry = expiresAt!.subtract(expiryBuffer);
    return now.isBefore(safeExpiry);
  }

  Duration? remainingAt(DateTime now) {
    if (unlockToken == null || expiresAt == null) {
      return null;
    }

    final remaining = expiresAt!.difference(now);
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  int? remainingWholeMinutesAt(DateTime now) {
    final remaining = remainingAt(now);
    if (remaining == null) {
      return null;
    }

    if (remaining == Duration.zero) {
      return 0;
    }

    return (remaining.inSeconds / 60).ceil();
  }

  ParentalGateState copyWith({
    String? unlockToken,
    DateTime? expiresAt,
    bool clear = false,
  }) {
    if (clear) {
      return const ParentalGateState();
    }

    return ParentalGateState(
      unlockToken: unlockToken ?? this.unlockToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

final parentalGateControllerProvider =
    StateNotifierProvider<ParentalGateController, ParentalGateState>((ref) {
      return ParentalGateController();
    });

class ParentalGateController extends StateNotifier<ParentalGateState> {
  ParentalGateController() : super(const ParentalGateState());

  void setUnlocked({required String token, required DateTime expiresAt}) {
    state = state.copyWith(unlockToken: token, expiresAt: expiresAt);
  }

  void clear() {
    state = state.copyWith(clear: true);
  }
}
