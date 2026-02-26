import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParentalGateState {
  const ParentalGateState({this.unlockToken, this.expiresAt});

  final String? unlockToken;
  final DateTime? expiresAt;

  bool get isUnlocked {
    if (unlockToken == null || expiresAt == null) {
      return false;
    }

    return DateTime.now().isBefore(expiresAt!);
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
