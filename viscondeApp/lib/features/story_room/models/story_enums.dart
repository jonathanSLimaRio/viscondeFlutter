enum StoryMode { parentNarrator, childChooser }

enum StoryStatus { draft, published, archived }

enum StoryStepKind { narration, childChoice, system }

enum StorySessionKind { presencial }

enum AgeBand { age4_5, age6_8, age9_10 }

enum VirtueSource { manual, auto }

StoryMode storyModeFromApi(String value) {
  switch (value) {
    case 'CHILD_CHOOSER':
      return StoryMode.childChooser;
    case 'PARENT_NARRATOR':
    default:
      return StoryMode.parentNarrator;
  }
}

String storyModeToApi(StoryMode value) {
  switch (value) {
    case StoryMode.childChooser:
      return 'CHILD_CHOOSER';
    case StoryMode.parentNarrator:
      return 'PARENT_NARRATOR';
  }
}

StoryStatus storyStatusFromApi(String value) {
  switch (value) {
    case 'PUBLISHED':
      return StoryStatus.published;
    case 'ARCHIVED':
      return StoryStatus.archived;
    case 'DRAFT':
    default:
      return StoryStatus.draft;
  }
}

String storyStatusToApi(StoryStatus value) {
  switch (value) {
    case StoryStatus.published:
      return 'PUBLISHED';
    case StoryStatus.archived:
      return 'ARCHIVED';
    case StoryStatus.draft:
      return 'DRAFT';
  }
}

StoryStepKind storyStepKindFromApi(String value) {
  switch (value) {
    case 'CHILD_CHOICE':
      return StoryStepKind.childChoice;
    case 'SYSTEM':
      return StoryStepKind.system;
    case 'NARRATION':
    default:
      return StoryStepKind.narration;
  }
}

String storyStepKindToApi(StoryStepKind value) {
  switch (value) {
    case StoryStepKind.childChoice:
      return 'CHILD_CHOICE';
    case StoryStepKind.system:
      return 'SYSTEM';
    case StoryStepKind.narration:
      return 'NARRATION';
  }
}

StorySessionKind storySessionKindFromApi(String? value) {
  switch (value) {
    case 'PRESENTIAL':
    case 'REMOTE':
    default:
      return StorySessionKind.presencial;
  }
}

AgeBand? ageBandFromApi(String? value) {
  switch (value) {
    case 'AGE_4_5':
      return AgeBand.age4_5;
    case 'AGE_6_8':
      return AgeBand.age6_8;
    case 'AGE_9_10':
      return AgeBand.age9_10;
    default:
      return null;
  }
}

String ageBandLabel(AgeBand? ageBand) {
  switch (ageBand) {
    case AgeBand.age4_5:
      return '4-5';
    case AgeBand.age6_8:
      return '6-8';
    case AgeBand.age9_10:
      return '9-10';
    case null:
      return '-';
  }
}

VirtueSource? virtueSourceFromApi(String? value) {
  switch (value) {
    case 'MANUAL':
      return VirtueSource.manual;
    case 'AUTO':
      return VirtueSource.auto;
    default:
      return null;
  }
}
