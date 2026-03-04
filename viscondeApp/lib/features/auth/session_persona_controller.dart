import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SessionPersona { parent, child }

class SessionPersonaState {
  const SessionPersonaState({this.persona});

  final SessionPersona? persona;

  bool get hasSelection => persona != null;

  SessionPersonaState copyWith({SessionPersona? persona, bool clear = false}) {
    if (clear) {
      return const SessionPersonaState();
    }
    return SessionPersonaState(persona: persona ?? this.persona);
  }
}

final sessionPersonaControllerProvider =
    StateNotifierProvider<SessionPersonaController, SessionPersonaState>((ref) {
      return SessionPersonaController();
    });

class SessionPersonaController extends StateNotifier<SessionPersonaState> {
  SessionPersonaController() : super(const SessionPersonaState());

  void selectParent() {
    state = state.copyWith(persona: SessionPersona.parent);
  }

  void selectChild() {
    state = state.copyWith(persona: SessionPersona.child);
  }

  void clear() {
    state = state.copyWith(clear: true);
  }
}
