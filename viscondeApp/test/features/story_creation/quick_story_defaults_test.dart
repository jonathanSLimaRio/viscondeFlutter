import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/story_creation/quick_story_defaults.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';

void main() {
  group('buildQuickStoryDefaults', () {
    test(
      'prioriza criança selecionada e coleção recente para tema/virtude',
      () {
        final children = <ChildProfile>[
          ChildProfile(
            id: 'child-1',
            name: 'Lia',
            birthDate: DateTime(2018, 3, 10),
            favoriteThemes: const <String>['Espaço'],
            isArchived: false,
          ),
          ChildProfile(
            id: 'child-2',
            name: 'Theo',
            birthDate: DateTime(2017, 1, 12),
            favoriteThemes: const <String>['Castelo'],
            isArchived: false,
          ),
        ];

        final templates = <ContentStoryTemplateModel>[
          const ContentStoryTemplateModel(
            id: 'tpl-1',
            slug: 'tpl',
            title: 'Template 6-8',
            description: 'template',
            ageBand: AgeBand.age6_8,
            version: 1,
            theme: StoryNamedRef(id: 'theme-1', slug: 'selva', name: 'Selva'),
            virtue: StoryNamedRef(
              id: 'virtue-1',
              slug: 'coragem',
              name: 'Coragem',
            ),
            defaultScenario: 'Selva iluminada',
            defaultObjective: 'Ajudar um amigo perdido',
            charactersCount: 2,
            nodesCount: 3,
          ),
        ];

        final collections = <StoryVaultCollectionItem>[
          StoryVaultCollectionItem(
            id: 'col-1',
            title: 'Aventura da Lia',
            theme: 'Piratas',
            virtue: const VirtueModel(
              id: 'virtue-recent',
              slug: 'amizade',
              name: 'Amizade',
              shortDescription: 'Amizade',
              iconKey: 'heart',
              sortOrder: 1,
            ),
            isFavorite: false,
            child: const StoryVaultChild(id: 'child-1', name: 'Lia'),
            episodesCount: 1,
            publishedCount: 0,
            draftCount: 1,
            lastReferenceAt: DateTime(2026, 3, 3, 10, 0),
            latestEpisode: null,
          ),
        ];

        final defaults = buildQuickStoryDefaults(
          children: children,
          collections: collections,
          templates: templates,
          selectedChildId: 'child-1',
          suggestedVirtueId: 'virtue-suggested',
          referenceDate: DateTime(2026, 3, 3),
        );

        expect(defaults, isNotNull);
        expect(defaults!.child.id, 'child-1');
        expect(defaults.ageBand, AgeBand.age6_8);
        expect(defaults.theme, 'Piratas');
        expect(defaults.virtueId, 'virtue-recent');
        expect(defaults.sourceTemplateId, 'tpl-1');
        expect(defaults.characters.first['name'], 'Lia');
      },
    );

    test('usa template por idade quando não há coleção recente', () {
      final children = <ChildProfile>[
        ChildProfile(
          id: 'child-1',
          name: 'Nina',
          birthDate: DateTime(2021, 6, 1),
          favoriteThemes: const <String>[],
          isArchived: false,
        ),
      ];

      final templates = <ContentStoryTemplateModel>[
        const ContentStoryTemplateModel(
          id: 'tpl-4-5',
          slug: 'tpl-4-5',
          title: 'Template 4-5',
          description: 'template',
          ageBand: AgeBand.age4_5,
          version: 1,
          theme: StoryNamedRef(id: 'theme-1', slug: 'jardim', name: 'Jardim'),
          virtue: StoryNamedRef(
            id: 'virtue-1',
            slug: 'empatia',
            name: 'Empatia',
          ),
          defaultScenario: 'Jardim mágico',
          defaultObjective: 'Cuidar das flores encantadas',
          charactersCount: 2,
          nodesCount: 3,
        ),
      ];

      final defaults = buildQuickStoryDefaults(
        children: children,
        collections: const <StoryVaultCollectionItem>[],
        templates: templates,
        referenceDate: DateTime(2026, 3, 3),
      );

      expect(defaults, isNotNull);
      expect(defaults!.ageBand, AgeBand.age4_5);
      expect(defaults.theme, 'Jardim');
      expect(defaults.virtueId, 'virtue-1');
      expect(defaults.scenario, 'Jardim mágico');
      expect(defaults.objective, 'Cuidar das flores encantadas');
    });

    test('aplica fallbacks quando não há template nem histórico', () {
      final children = <ChildProfile>[
        ChildProfile(
          id: 'child-1',
          name: 'Gael',
          birthDate: DateTime(2015, 5, 9),
          favoriteThemes: const <String>[],
          isArchived: false,
        ),
      ];

      final defaults = buildQuickStoryDefaults(
        children: children,
        collections: const <StoryVaultCollectionItem>[],
        templates: const <ContentStoryTemplateModel>[],
        suggestedVirtueId: 'virtue-suggested',
        referenceDate: DateTime(2026, 3, 3),
      );

      expect(defaults, isNotNull);
      expect(defaults!.theme, 'Aventura');
      expect(defaults.scenario, 'Bosque encantado');
      expect(defaults.objective, 'Aprender algo novo com coragem e gentileza.');
      expect(defaults.virtueId, 'virtue-suggested');
      expect(defaults.sourceTemplateId, isNull);
    });
  });
}
