enum ViscondeArtKey {
  paperTexture,
  heroTreasure,
  heroUnderwater,
  heroCastle,
  heroSpace,
  heroForest,
  avatarParent,
  avatarChild,
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
    ViscondeArtKey.iconEmpathy: 'assets/design/icons/empathy.png',
    ViscondeArtKey.iconCourage: 'assets/design/icons/courage.png',
    ViscondeArtKey.iconRespect: 'assets/design/icons/respect.png',
    ViscondeArtKey.iconGratitude: 'assets/design/icons/gratitude.png',
    ViscondeArtKey.iconStory: 'assets/design/icons/story.png',
    ViscondeArtKey.iconLibrary: 'assets/design/icons/library.png',
    ViscondeArtKey.logoVisconde: 'assets/design/logos/logo_visconde.png',
  };

  static String resolve(ViscondeArtKey key) {
    return _assets[key] ?? _assets[ViscondeArtKey.paperTexture]!;
  }
}
