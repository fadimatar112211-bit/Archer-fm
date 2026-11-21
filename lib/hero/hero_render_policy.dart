/// Production visual routing during the reference-approved 2.5D migration.
///
/// Only Shadow has an approved user-supplied sprite source integrated today.
/// The other roster members stay on their existing GLB visuals until their
/// replacement sprite sheets pass reference and animation acceptance.
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
