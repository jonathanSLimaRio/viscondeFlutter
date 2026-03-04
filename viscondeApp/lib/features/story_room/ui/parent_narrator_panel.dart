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
    this.loading = false,
  });

  final ValueChanged<String> onSaveNarration;
  final ValueChanged<String?> onRequestIdeas;
  final List<String> ideas;
  final String? ideasSource;
  final bool ideasSafetyAdjusted;
  final bool loading;

  @override
  State<ParentNarratorPanel> createState() => _ParentNarratorPanelState();
}

class _ParentNarratorPanelState extends State<ParentNarratorPanel> {
  final _narrationController = TextEditingController();
  final _hintController = TextEditingController();

  @override
  void dispose() {
    _narrationController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  void _saveNarration() {
    final text = _narrationController.text.trim();
    if (text.isEmpty) {
      return;
    }

    widget.onSaveNarration(text);
    _narrationController.clear();
  }

  @override
  Widget build(BuildContext context) {
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
              child: ViscondePrimaryCta(
                onPressed: widget.loading ? null : _saveNarration,
                icon: Icons.save_outlined,
                label: 'Salvar Etapa',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F5B6F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: widget.loading
                    ? null
                    : () {
                        widget.onRequestIdeas(_hintController.text.trim());
                      },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Gerar ideia'),
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
                title: Text(idea),
                trailing: IconButton(
                  icon: const Icon(Icons.add_comment_outlined),
                  onPressed: widget.loading
                      ? null
                      : () {
                          widget.onSaveNarration(idea);
                        },
                  tooltip: 'Usar ideia como narrativa',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
