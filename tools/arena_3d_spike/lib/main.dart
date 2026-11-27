import 'package:flutter/material.dart' hide BoxShape;
import 'package:flutter/scheduler.dart';
import 'package:stage_3d/stage_3d.dart';

const _camera = StageCamera.orbit(
  target: Vector3(0, 0.8, 0),
  yaw: -0.55,
  pitch: 0.42,
  distance: 8,
);

void main() => runApp(const Arena3DSpikeApp());

class Arena3DSpikeApp extends StatelessWidget {
  const Arena3DSpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const Arena3DSpikeScene(),
      );
}

class Arena3DSpikeScene extends StatefulWidget {
  const Arena3DSpikeScene({super.key});

  @override
  State<Arena3DSpikeScene> createState() => _Arena3DSpikeSceneState();
}

class _Arena3DSpikeSceneState extends State<Arena3DSpikeScene>
    with SingleTickerProviderStateMixin {
  late final PhysicsWorld _world;
  late final StageScene _scene;
  late final OrbitCamera _fallbackCamera;
  late final Ticker _ticker;
  late final FilamentViewportController _viewport;
  late final RenderEnvironmentController _environment;
  late final RenderLightController _lights;
  late final RenderModelController _models;
  late final PhysicsBodyComponent _rangerBody;
  late final RenderModelComponent _rangerModel;
  late final List<TexturedMeshPrototype> _meshes;
  Duration? _lastTick;
  String _status = 'Waiting for Filament renderer';

  @override
  void initState() {
    super.initState();
    _world = createPhysicsWorld();
    _scene = StageScene();
    _fallbackCamera = OrbitCamera();
    _viewport = FilamentViewportController()..setCamera(_camera);
    _environment = RenderEnvironmentController(
      initialEnvironment: const RenderEnvironment(
        skyColor: Vector3(0.36, 0.55, 0.72),
        ambientIntensity: 38000,
        reflectionIntensity: 0.8,
      ),
    );
    _lights = RenderLightController()
      ..createLight(
        const DirectionalLight(
          direction: Vector3(-0.4, -1, -0.35),
          intensity: 105000,
        ),
      );
    _models = RenderModelController();
    _meshes = [_groundMesh()];

    final ground = PhysicsBodyComponent(
      _world,
      settings: const RigidBodySettings(
        shape: BoxShape(halfWidth: 5, halfHeight: 0.15, halfDepth: 5),
        motionType: MotionType.static,
        transform: PhysicsTransform(position: Vector3(0, -0.15, 0)),
      ),
    );
    _scene.add(StageObject.node('ground', components: [ground]));

    final rangerAsset = _models.loadAsset(
      const ModelAsset(
        assetPath: 'assets/ranger_animated.glb',
        verticalAnchor: ModelVerticalAnchor.bottom,
        castShadows: true,
        receiveShadows: true,
      ),
    );
    _rangerBody = PhysicsBodyComponent(
      _world,
      settings: const RigidBodySettings(
        shape: CapsuleShape(halfHeight: 0.55, radius: 0.32),
        motionType: MotionType.kinematic,
        transform: PhysicsTransform(position: Vector3(-0.8, 0, 0)),
      ),
    );
    _rangerModel = RenderModelComponent(
      controller: _models,
      asset: rangerAsset,
      visualOffset: const Vector3(0, 0, 0),
    );
    _scene.add(
      StageObject.node('archer-fm-ranger', components: [_rangerBody, _rangerModel]),
    );

    final monsterAsset = _models.loadAsset(
      const ModelAsset(
        assetPath: 'assets/stone-golem.glb',
        verticalAnchor: ModelVerticalAnchor.bottom,
        castShadows: true,
        receiveShadows: true,
      ),
    );
    final monsterBody = PhysicsBodyComponent(
      _world,
      settings: const RigidBodySettings(
        shape: CapsuleShape(halfHeight: 0.7, radius: 0.48),
        motionType: MotionType.kinematic,
        transform: PhysicsTransform(position: Vector3(1.1, 0, 0)),
      ),
    );
    _scene.add(
      StageObject.node(
        'archer-fm-stone-golem',
        components: [
          monsterBody,
          RenderModelComponent(controller: _models, asset: monsterAsset),
        ],
      ),
    );

    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _onRendererReady() async {
    try {
      final animations = await _models.getAnimations(_rangerModel.requireInstance);
      if (!mounted) return;
      if (animations.isNotEmpty) {
        _models.playAnimation(
          _rangerModel.requireInstance,
          animationIndex: animations.first.index,
        );
      }
      setState(() {
        _status = animations.isEmpty
            ? 'Filament ready • GLB models loaded'
            : 'Filament ready • Ranger: ${animations.first.name}';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Animation check failed: $error');
    }
  }

  void _onTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;
    final delta = (elapsed - previous).inMicroseconds /
        Duration.microsecondsPerSecond;
    _world.step(delta);
    _scene.update(delta);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scene.dispose();
    _fallbackCamera.dispose();
    _world.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: FilamentViewport(
                cube: _rangerBody.transform,
                fallbackCamera: _fallbackCamera,
                controller: _viewport,
                environmentController: _environment,
                lightController: _lights,
                modelController: _models,
                meshPrototypes: _meshes,
                onRendererReady: _onRendererReady,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xdd101820),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ARCHER FM • 3D RENDERER SPIKE\n$_status',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

TexturedMeshPrototype _groundMesh() {
  const texture = MeshTexturePrototype(
    primaryColor: Color(0xff315b36),
    secondaryColor: Color(0xff6d8c45),
    repeatU: 8,
    repeatV: 8,
  );
  return TexturedMeshPrototype.plane(
    width: 10,
    depth: 10,
    texture: texture,
    material: MeshMaterialPrototype.checker(texture, roughnessFactor: 0.94),
    collider: const MeshColliderPrototype.staticBox(
      BoxShape(halfWidth: 5, halfHeight: 0.15, halfDepth: 5),
    ),
  );
}
