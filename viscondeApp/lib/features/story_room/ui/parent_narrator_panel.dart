import 'package:flutter/material.dart';

import '../../../design_system/visconde.dart';

class ParentNarratorPanel extends StatefulWidget {
  const ParentNarratorPanel({
    super.key,
    required this.onSaveNarration,
    required this.onRequestIdeas,
    required this.ideas,
    required this.ideasSource,
    required this.ideasSafetyAdjusted,
    this.isSavingStep = false,
    this.isRequestingIdeas = false,
  });

  final Future<bool> Function(String) onSaveNarration;
  final ValueChanged<String?> onRequestIdeas;
  final List<String> ideas;
  final String? ideasSource;
  final bool ideasSafetyAdjusted;
  final bool isSavingStep;
  final bool isRequestingIdeas;

  @override
  State<ParentNarratorPanel> createState() => _ParentNarratorPanelState();
}

class _ParentNarratorPanelState extends State<ParentNarratorPanel> {
  final _narrationController = TextEditingController();
  final _hintController = TextEditingController();
  bool _savingNarration = false;

  void _applyIdeaToNarration(String idea) {
    _narrationController.text = idea;
    _narrationController.selection = TextSelection.fromPosition(
      TextPosition(offset: _narrationController.text.length),
    );
  }

  @override
  void dispose() {
    _narrationController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _saveNarration() async {
    final text = _narrationController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() => _savingNarration = true);
    final saved = await widget.onSaveNarration(text);
    if (!mounted) {
      return;
    }
    setState(() => _savingNarration = false);

    if (saved) {
      _narrationController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSavingStep = widget.isSavingStep || _savingNarration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF2E6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4B483)),
          ),
          child: TextField(
            controller: _narrationController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Escreva a próxima parte da história...',
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                key: const ValueKey<String>('story_room_generate_idea_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F5B6F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: widget.isRequestingIdeas
                    ? null
                    : () {
                        final hint = _hintController.text.trim();
                        widget.onRequestIdeas(hint.isEmpty ? null : hint);
                      },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isRequestingIdeas) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.isRequestingIdeas ? 'Gerando...' : 'Gerar ideia',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ViscondePrimaryCta(
                key: const ValueKey<String>('story_room_next_step_button'),
                onPressed: isSavingStep ? null : _saveNarration,
                icon: Icons.arrow_forward_rounded,
                label: 'Próximo passo',
              ),
            ),
          ],
        ),
        if (widget.ideas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Sugestões (${widget.ideasSource ?? 'TEMPLATE'})${widget.ideasSafetyAdjusted ? ' · ajustado para segurança' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...widget.ideas.map(
            (idea) => ViscondeGlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: isSavingStep ? null : () => _applyIdeaToNarration(idea),
                title: Text(idea),
                trailing: IconButton(
                  icon: const Icon(Icons.add_comment_outlined),
                  onPressed: isSavingStep
                      ? null
                      : () => _applyIdeaToNarration(idea),
                  tooltip: 'Preencher narrativa com esta ideia',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
