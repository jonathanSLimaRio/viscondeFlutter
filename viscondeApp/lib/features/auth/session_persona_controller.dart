import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SessionPersona { parent, child }

enum SessionPresenceMode { separated, together }

class SessionPersonaState {
  const SessionPersonaState({
    this.persona,
    this.presenceMode = SessionPresenceMode.separated,
  });

  final SessionPersona? persona;
  final SessionPresenceMode presenceMode;

  bool get hasSelection => persona != null;
  bool get isChildMode => persona == SessionPersona.child;
  bool get isTogetherMode => presenceMode == SessionPresenceMode.together;

  SessionPersonaState copyWith({
    SessionPersona? persona,
    SessionPresenceMode? presenceMode,
    bool clear = false,
  }) {
    if (clear) {
      return const SessionPersonaState();
    }
    return SessionPersonaState(
      persona: persona ?? this.persona,
      presenceMode: presenceMode ?? this.presenceMode,
    );
  }
}

final sessionPersonaControllerProvider =
    StateNotifierProvider<SessionPersonaController, SessionPersonaState>((ref) {
      return SessionPersonaController();
    });

class SessionPersonaController extends StateNotifier<SessionPersonaState> {
  SessionPersonaController() : super(const SessionPersonaState());

  void selectParent() {
    state = state.copyWith(
      persona: SessionPersona.parent,
      presenceMode: SessionPresenceMode.separated,
    );
  }

  void selectChild() {
    state = state.copyWith(
      persona: SessionPersona.child,
      presenceMode: SessionPresenceMode.separated,
    );
  }

  void selectParentTogether() {
    state = state.copyWith(
      persona: SessionPersona.parent,
      presenceMode: SessionPresenceMode.together,
    );
  }

  void clear() {
    state = state.copyWith(clear: true);
  }
}
