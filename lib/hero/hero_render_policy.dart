/// Production visual routing during the reference-approved 2.5D migration.
///
/// Final production target: all four heroes use reference-approved 2.5D
/// sprite actors. This route table is only a migration safety gate: it prevents
/// rejected atlases from being exposed while replacement packs are built.
enum HeroVisualRoute {
  approvedSpritePilot,
  glbPrimary,
}

class HeroRenderPolicy {
  HeroRenderPolicy._();

  static const Set<String> _approvedSpritePilotIds = {'shadow'};

  static HeroVisualRoute routeFor(String heroId) =>
      _approvedSpritePilotIds.contains(heroId)
          ? HeroVisualRoute.approvedSpritePilot
          : HeroVisualRoute.glbPrimary;

  /// True only when the hero's sprite art has passed the visual acceptance
  /// gate. A populated manifest or a failed GLB load is not sufficient.
  static bool allowsSpriteAtlas(String heroId) =>
      routeFor(heroId) == HeroVisualRoute.approvedSpritePilot;
}
