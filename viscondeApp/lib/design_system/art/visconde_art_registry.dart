enum ViscondeArtKey {
  paperTexture,
  heroTreasure,
  heroUnderwater,
  heroCastle,
  heroSpace,
  heroForest,
  avatarParent,
  avatarChild,
  mascotWavingControllerBook,
  mascotPointingScroll,
  mascotEnchantedHearts,
  mascotStudyingDesk,
  mascotSpeakingMic,
  mascotThumbsUpController,
  mascotReadingBook,
  mascotReadingBookClose,
  mascotObservingSpyglass,
  mascotWinkingWavingController,
  mascotSeriousController,
  mascotPotionPalette,
  iconEmpathy,
  iconCourage,
  iconRespect,
  iconGratitude,
  iconStory,
  iconLibrary,
  logoVisconde,
}

class ViscondeArtRegistry {
  const ViscondeArtRegistry._();

  static const Map<ViscondeArtKey, String> _assets = {
    ViscondeArtKey.paperTexture: 'assets/design/backgrounds/paper_texture.png',
    ViscondeArtKey.heroTreasure: 'assets/design/heroes/treasure.png',
    ViscondeArtKey.heroUnderwater: 'assets/design/heroes/underwater.png',
    ViscondeArtKey.heroCastle: 'assets/design/heroes/castle.png',
    ViscondeArtKey.heroSpace: 'assets/design/heroes/space.png',
    ViscondeArtKey.heroForest: 'assets/design/heroes/forest.png',
    ViscondeArtKey.avatarParent: 'assets/design/avatars/parent.png',
    ViscondeArtKey.avatarChild: 'assets/design/avatars/child.png',
    ViscondeArtKey.mascotWavingControllerBook:
        'assets/design/mascot/mascote_acenando_com_controle_e_livro.png',
    ViscondeArtKey.mascotPointingScroll:
        'assets/design/mascot/mascote_apontando_com_pergaminho.png',
    ViscondeArtKey.mascotEnchantedHearts:
        'assets/design/mascot/mascote_encantado_com_coracoes.png',
    ViscondeArtKey.mascotStudyingDesk:
        'assets/design/mascot/mascote_estudando_na_mesa.png',
    ViscondeArtKey.mascotSpeakingMic:
        'assets/design/mascot/mascote_falando_no_microfone.png',
    ViscondeArtKey.mascotThumbsUpController:
        'assets/design/mascot/mascote_joinha_com_controle.png',
    ViscondeArtKey.mascotReadingBook:
        'assets/design/mascot/mascote_lendo_livro.png',
    ViscondeArtKey.mascotReadingBookClose:
        'assets/design/mascot/mascote_lendo_livro_de_perto.png',
    ViscondeArtKey.mascotObservingSpyglass:
        'assets/design/mascot/mascote_observando_com_luneta.png',
    ViscondeArtKey.mascotWinkingWavingController:
        'assets/design/mascot/mascote_piscando_acenando_com_controle.png',
    ViscondeArtKey.mascotSeriousController:
        'assets/design/mascot/mascote_segura_controle_serio.png',
    ViscondeArtKey.mascotPotionPalette:
        'assets/design/mascot/mascote_segura_pocao_e_paleta.png',
    ViscondeArtKey.iconEmpathy: 'assets/design/icons/empathy.png',
    ViscondeArtKey.iconCourage: 'assets/design/icons/courage.png',
    ViscondeArtKey.iconRespect: 'assets/design/icons/respect.png',
    ViscondeArtKey.iconGratitude: 'assets/design/icons/gratitude.png',
    ViscondeArtKey.iconStory: 'assets/design/icons/story.png',
    ViscondeArtKey.iconLibrary: 'assets/design/icons/library.png',
    ViscondeArtKey.logoVisconde: 'assets/design/logos/viscondeLogo.png',
  };

  static String resolve(ViscondeArtKey key) {
    return _assets[key] ?? _assets[ViscondeArtKey.paperTexture]!;
  }
}
