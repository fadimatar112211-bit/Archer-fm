/// Production visual routing while all four reference-faithful 3D heroes are
/// brought through visual acceptance.
///
/// GLB is the final in-match character pipeline. Sprite atlases are legacy or
/// temporary review fallbacks; an atlas must never be promoted just because a
/// GLB is unavailable or an atlas manifest exists.
enum HeroVisualRoute {
  approvedSpritePilot,
  glbPrimary,
}

class HeroRenderPolicy {
  HeroRenderPolicy._();

  // Shadow's approved sprite pilot is temporary until its production GLB passes
  // the same face, weapon, animation and gameplay-scale visual review.
  static const Set<String> _approvedSpritePilotIds = {'shadow'};

  static HeroVisualRoute routeFor(String heroId) =>
      _approvedSpritePilotIds.contains(heroId)
          ? HeroVisualRoute.approvedSpritePilot
          : HeroVisualRoute.glbPrimary;

  /// True only for the explicitly approved temporary sprite fallback.
  /// This does not mean the hero has passed final 3D visual acceptance.
  static bool allowsSpriteAtlas(String heroId) =>
      routeFor(heroId) == HeroVisualRoute.approvedSpritePilot;
}
