enum AdminPromptKind { ideaSystem, ideaFallback, narratorHint }

enum AdminStoryTemplateNodeKind { start, narration, choice, end }

enum AdminModerationPolicy { block, sanitize }

enum AdminModerationScope {
  userName,
  childName,
  storyText,
  chatText,
  templateText,
}

AdminPromptKind adminPromptKindFromApi(String? value) {
  switch (value) {
    case 'IDEA_SYSTEM':
      return AdminPromptKind.ideaSystem;
    case 'NARRATOR_HINT':
      return AdminPromptKind.narratorHint;
    case 'IDEA_FALLBACK':
    default:
      return AdminPromptKind.ideaFallback;
  }
}

String adminPromptKindToApi(AdminPromptKind value) {
  switch (value) {
    case AdminPromptKind.ideaSystem:
      return 'IDEA_SYSTEM';
    case AdminPromptKind.narratorHint:
      return 'NARRATOR_HINT';
    case AdminPromptKind.ideaFallback:
      return 'IDEA_FALLBACK';
  }
}

AdminStoryTemplateNodeKind adminStoryTemplateNodeKindFromApi(String? value) {
  switch (value) {
    case 'START':
      return AdminStoryTemplateNodeKind.start;
    case 'END':
      return AdminStoryTemplateNodeKind.end;
    case 'CHOICE':
      return AdminStoryTemplateNodeKind.choice;
    case 'NARRATION':
    default:
      return AdminStoryTemplateNodeKind.narration;
  }
}

String adminStoryTemplateNodeKindToApi(AdminStoryTemplateNodeKind value) {
  switch (value) {
    case AdminStoryTemplateNodeKind.start:
      return 'START';
    case AdminStoryTemplateNodeKind.end:
      return 'END';
    case AdminStoryTemplateNodeKind.choice:
      return 'CHOICE';
    case AdminStoryTemplateNodeKind.narration:
      return 'NARRATION';
  }
}

AdminModerationPolicy adminModerationPolicyFromApi(String? value) {
  switch (value) {
    case 'SANITIZE':
      return AdminModerationPolicy.sanitize;
    case 'BLOCK':
    default:
      return AdminModerationPolicy.block;
  }
}

String adminModerationPolicyToApi(AdminModerationPolicy value) {
  switch (value) {
    case AdminModerationPolicy.block:
      return 'BLOCK';
    case AdminModerationPolicy.sanitize:
      return 'SANITIZE';
  }
}

AdminModerationScope adminModerationScopeFromApi(String? value) {
  switch (value) {
    case 'USER_NAME':
      return AdminModerationScope.userName;
    case 'CHILD_NAME':
      return AdminModerationScope.childName;
    case 'STORY_TEXT':
      return AdminModerationScope.storyText;
    case 'CHAT_TEXT':
      return AdminModerationScope.chatText;
    case 'TEMPLATE_TEXT':
    default:
      return AdminModerationScope.templateText;
  }
}

String adminModerationScopeToApi(AdminModerationScope value) {
  switch (value) {
    case AdminModerationScope.userName:
      return 'USER_NAME';
    case AdminModerationScope.childName:
      return 'CHILD_NAME';
    case AdminModerationScope.storyText:
      return 'STORY_TEXT';
    case AdminModerationScope.chatText:
      return 'CHAT_TEXT';
    case AdminModerationScope.templateText:
      return 'TEMPLATE_TEXT';
  }
}
