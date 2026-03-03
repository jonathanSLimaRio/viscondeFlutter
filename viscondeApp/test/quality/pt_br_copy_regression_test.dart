import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _ForbiddenToken {
  const _ForbiddenToken(this.regex, this.suggestion);

  final RegExp regex;
  final String suggestion;
}

void main() {
  test('copy PT-BR não contém termos sem acento conhecidos', () {
    final forbidden = <_ForbiddenToken>[
      _ForbiddenToken(RegExp(r'\bTitulo\b', caseSensitive: false), 'Título'),
      _ForbiddenToken(
        RegExp(r'\bDescricao\b', caseSensitive: false),
        'Descrição',
      ),
      _ForbiddenToken(RegExp(r'\bCenario\b', caseSensitive: false), 'Cenário'),
      _ForbiddenToken(
        RegExp(r'Faixa etaria', caseSensitive: false),
        'Faixa etária',
      ),
      _ForbiddenToken(RegExp(r'padrao', caseSensitive: false), 'padrão'),
      _ForbiddenToken(RegExp(r'virgula', caseSensitive: false), 'vírgula'),
      _ForbiddenToken(RegExp(r'digitos', caseSensitive: false), 'dígitos'),
      _ForbiddenToken(RegExp(r'codigo', caseSensitive: false), 'código'),
      _ForbiddenToken(RegExp(r'valido', caseSensitive: false), 'válido'),
      _ForbiddenToken(
        RegExp(r'necessario', caseSensitive: false),
        'necessário',
      ),
      _ForbiddenToken(RegExp(r'reacoes', caseSensitive: false), 'reações'),
      _ForbiddenToken(RegExp(r'\bopcao\b', caseSensitive: false), 'opção'),
      _ForbiddenToken(RegExp(r'\bopcoes\b', caseSensitive: false), 'opções'),
      _ForbiddenToken(RegExp(r'\bSessao\b', caseSensitive: false), 'Sessão'),
      _ForbiddenToken(
        RegExp(r'sinalizacao', caseSensitive: false),
        'sinalização',
      ),
      _ForbiddenToken(
        RegExp(r'sincronizacao', caseSensitive: false),
        'sincronização',
      ),
      _ForbiddenToken(RegExp(r'decisao', caseSensitive: false), 'decisão'),
      _ForbiddenToken(
        RegExp(r'Inesquecivel', caseSensitive: false),
        'Inesquecível',
      ),
      _ForbiddenToken(RegExp(r'Sugestoes', caseSensitive: false), 'Sugestões'),
      _ForbiddenToken(RegExp(r'seguranca', caseSensitive: false), 'segurança'),
      _ForbiddenToken(RegExp(r'familia', caseSensitive: false), 'família'),
    ];

    final featureFiles = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final issues = <String>[];
    final stringLiteralPattern = RegExp(
      "'([^'\\\\]|\\\\.)*'|\"([^\"\\\\]|\\\\.)*\"",
    );

    for (final file in featureFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final literals = stringLiteralPattern
            .allMatches(line)
            .map((m) => m.group(0)!)
            .toList();

        if (literals.isEmpty) {
          continue;
        }

        for (final literal in literals) {
          for (final token in forbidden) {
            if (token.regex.hasMatch(literal)) {
              issues.add(
                '${file.path}:${i + 1} contém "$literal"; use "${token.suggestion}".',
              );
            }
          }
        }
      }
    }

    expect(
      issues,
      isEmpty,
      reason: issues.isEmpty
          ? null
          : 'Encontrados termos PT-BR sem acento conhecidos:\n${issues.join('\n')}',
    );
  });
}
