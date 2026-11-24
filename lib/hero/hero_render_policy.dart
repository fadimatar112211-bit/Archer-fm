/// Production render routing for the four playable heroes.
///
/// All four heroes use their rigged GLB models in the live arena. The Shadow
/// sprite atlas is only a partial walk-cycle proof; its held action poses are
/// not production-ready, so it must not replace the complete animated GLB.
enum HeroVisualRoute {
  approvedSpritePilot,
  glbPrimary,
}

class HeroRenderPolicy {
  HeroRenderPolicy._();

  // No hero currently passes the full sprite-action acceptance gate.
  static const Set<String> _approvedSpritePilotIds = {};

  static HeroVisualRoute routeFor(String heroId) =>
      _approvedSpritePilotIds.contains(heroId)
          ? HeroVisualRoute.approvedSpritePilot
          : HeroVisualRoute.glbPrimary;

  /// True only for a hero whose complete sprite action set passed acceptance.
  /// Keep false for Shadow until its held action poses are replaced.
  static bool allowsSpriteAtlas(String heroId) =>
      routeFor(heroId) == HeroVisualRoute.approvedSpritePilot;
}
