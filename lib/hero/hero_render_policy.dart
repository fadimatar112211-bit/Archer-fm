/// Temporary render routing during the approved 2.5D sprite migration.
///
/// Shadow is the first sprite proof. The other heroes retain their last safe
/// GLB route until their reference-matched sprite packs pass the conversion
/// plan's visual and runtime gates. A missing GLB must never promote an
/// unapproved atlas.
enum HeroVisualRoute {
  approvedSpritePilot,
  glbPrimary,
}

class HeroRenderPolicy {
  HeroRenderPolicy._();

  // Shadow is the first approved sprite-pipeline pilot. Its walk sheet is the
  // source proof; action poses remain explicit safe holds until real art exists.
  static const Set<String> _approvedSpritePilotIds = {'shadow'};

  static HeroVisualRoute routeFor(String heroId) =>
      _approvedSpritePilotIds.contains(heroId)
          ? HeroVisualRoute.approvedSpritePilot
          : HeroVisualRoute.glbPrimary;

  /// True only for the explicitly approved Shadow sprite pilot during migration.
  /// This does not imply that every required Shadow animation is complete.
  static bool allowsSpriteAtlas(String heroId) =>
      routeFor(heroId) == HeroVisualRoute.approvedSpritePilot;
}
