import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

/// Two 4K monitors at 150% scale, side by side, DP-1 on the left and primary.
/// A disabled TV and a rotated monitor are there to be filtered/handled.
final kscreenJson = jsonEncode({
  'outputs': [
    {'name': 'DP-2', 'enabled': true, 'connected': true, 'pos': {'x': 2560, 'y': 0}, 'size': {'width': 3840, 'height': 2160}, 'rotation': 1, 'priority': 2},
    {'name': 'DP-1', 'enabled': true, 'connected': true, 'pos': {'x': 0, 'y': 0}, 'size': {'width': 3840, 'height': 2160}, 'rotation': 1, 'priority': 1},
    {'name': 'HDMI-A-1', 'enabled': false, 'connected': true, 'pos': {'x': 0, 'y': 0}, 'size': {'width': 1920, 'height': 1080}, 'rotation': 1, 'priority': 0},
  ],
});

const plasmaScreensJson =
    '[{"i":0,"x":0,"y":0,"w":2560,"h":1440},{"i":1,"x":2560,"y":0,"w":2560,"h":1440}]';

class FakePlasma implements PlasmaShell {
  final scripts = <String>[];
  String applyResult = '{"applied":1}';

  @override
  Future<String> evaluateScript(String script) async {
    scripts.add(script);
    return script.contains('screenGeometry') ? plasmaScreensJson : applyResult;
  }
}

void main() {
  late FakePlasma plasma;
  late List<List<String>> commands;
  late KdeSetter setter;
  late Directory temp;
  late String image;

  setUp(() async {
    plasma = FakePlasma();
    commands = [];
    setter = KdeSetter(
      shell: plasma,
      runProcess: (exe, args) async {
        commands.add([exe, ...args]);
        return ProcessResult(0, 0, exe == 'kscreen-doctor' ? kscreenJson : '', '');
      },
    );
    temp = await Directory.systemTemp.createTemp('wf_kde_');
    image = p.join(temp.path, 'my wallpaper.jpg');
    await File(image).writeAsString('x');
  });

  tearDown(() => temp.delete(recursive: true));

  test('kscreen output parsing skips disabled monitors and handles rotation', () {
    final rotated = jsonEncode({
      'outputs': [
        {'name': 'DP-3', 'enabled': true, 'connected': true, 'pos': {'x': 0, 'y': 0}, 'size': {'width': 2560, 'height': 1440}, 'rotation': 2, 'priority': 1},
      ],
    });
    expect(KdeSetter.parseKScreenOutputs(kscreenJson).map((o) => o.name), ['DP-2', 'DP-1']);
    final r = KdeSetter.parseKScreenOutputs(rotated).single;
    expect((r.width, r.height), (1440, 2560));
  });

  test('targets: monitors named by position with physical sizes, plus lock screen', () async {
    final targets = await setter.targets();

    expect(targets.map((t) => t.label), [
      'Left monitor (DP-1)',
      'Right monitor (DP-2)',
      'Lock screen',
    ]);
    expect(targets.map((t) => t.id), ['DP-1', 'DP-2', KdeSetter.lockTargetId]);
    expect(targets.first.width, 3840, reason: 'physical, not the 2560 logical width');
    expect(targets.first.isPrimary, isTrue);
    expect(targets.last.surface, TargetSurface.lock);
  });

  test('without kscreen-doctor, falls back to Plasma geometry and generic ids', () async {
    final bare = KdeSetter(
      shell: plasma,
      runProcess: (exe, args) async => throw const ProcessException('kscreen-doctor', [], 'not found'),
    );
    final targets = await bare.targets();
    expect(targets.map((t) => t.id), ['screen-0', 'screen-1', 'lock']);
    expect(targets.first.label, 'Left monitor');
    expect(targets.first.width, 2560);
  });

  test('apply sends one script that targets the right screen index', () async {
    final right = (await setter.targets())[1];
    plasma.scripts.clear();

    await setter.apply([Assignment(target: right, imagePath: image, fit: FitMode.fit)]);

    final script = plasma.scripts.last;
    final config = jsonDecode(RegExp(r'var assignments = (.*);').firstMatch(script)!.group(1)!) as Map;
    expect(config.keys, ['1'], reason: 'DP-2 is Plasma screen 1');
    expect(config['1']['image'], Uri.file(image).toString());
    expect(config['1']['image'], contains('my%20wallpaper.jpg'));
    expect(config['1']['fill'], 1);
    expect(commands.where((c) => c.first == 'kwriteconfig6'), isEmpty);
  });

  test('apply keeps a compatible wallpaper plugin such as Blurred Wallpaper', () async {
    final left = (await setter.targets()).first;
    plasma.scripts.clear();

    await setter.apply([Assignment(target: left, imagePath: image)]);

    final script = plasma.scripts.last;
    final plugins = jsonDecode(RegExp(r'var imagePlugins = (.*);').firstMatch(script)!.group(1)!) as List;
    expect(plugins, containsAll(['org.kde.image', 'a2n.blur']));
    expect(script, isNot(contains('d.wallpaperPlugin = "org.kde.image"')),
        reason: 'the plugin must not be forced back to the plain image one');
    expect(script, contains('["Wallpaper", plugin, "General"]'));
  });

  group('blurred wallpaper setting', () {
    String forcedPlugin(String script) =>
        RegExp(r'var forcedPlugin = (.*);').firstMatch(script)!.group(1)!;

    Future<String> applyWith({required bool prefer, required bool installed}) async {
      final kde = KdeSetter(
        shell: plasma,
        runProcess: (exe, args) async =>
            ProcessResult(0, 0, exe == 'kscreen-doctor' ? kscreenJson : '', ''),
        preferBlur: () async => prefer,
        blurPluginInstalled: () => installed,
      );
      final left = (await kde.targets()).first;
      plasma.scripts.clear();
      await kde.apply([Assignment(target: left, imagePath: image)]);
      return plasma.scripts.last;
    }

    test('switches screens to the blur plugin when wanted and installed', () async {
      expect(forcedPlugin(await applyWith(prefer: true, installed: true)), '"a2n.blur"');
    });

    test('leaves the plugin alone when not wanted, or not installed', () async {
      expect(forcedPlugin(await applyWith(prefer: false, installed: true)), 'null');
      expect(forcedPlugin(await applyWith(prefer: true, installed: false)), 'null');
    });

    test('finds the plugin in the user or system data directories', () async {
      final user = p.join(temp.path, 'user');
      final system = p.join(temp.path, 'system');
      bool installed() => KdeSetter.isBlurPluginInstalled(
        environment: {'HOME': temp.path, 'XDG_DATA_HOME': user, 'XDG_DATA_DIRS': system},
      );
      expect(installed(), isFalse);

      final package = Directory(p.join(system, 'plasma', 'wallpapers', 'a2n.blur'));
      await package.create(recursive: true);
      await File(p.join(package.path, 'metadata.json')).writeAsString('{}');
      expect(installed(), isTrue);
    });
  });

  test('different images on both monitors go in one script', () async {
    final second = p.join(temp.path, 'b.png');
    await File(second).writeAsString('y');
    final targets = await setter.targets();
    plasma
      ..scripts.clear()
      ..applyResult = '{"applied":2}';

    await setter.apply([
      Assignment(target: targets[0], imagePath: image),
      Assignment(target: targets[1], imagePath: second),
    ]);

    final applyScripts = plasma.scripts.where((s) => s.contains('writeConfig'));
    expect(applyScripts, hasLength(1));
    expect(applyScripts.single, allOf(contains('my%20wallpaper.jpg'), contains('b.png')));
  });

  test('lock screen goes through kwriteconfig6', () async {
    final lock = (await setter.targets()).last;

    await setter.apply([Assignment(target: lock, imagePath: image)]);

    final writes = commands.where((c) => c.first == 'kwriteconfig6').toList();
    expect(writes, hasLength(4));
    expect(writes.first, containsAllInOrder(['--group', 'Greeter', '--key', 'WallpaperPlugin', 'org.kde.image']));
    expect(writes[1], containsAllInOrder(['--group', 'org.kde.image', '--group', 'General', '--key', 'Image', Uri.file(image).toString()]));
    expect(plasma.scripts.where((s) => s.contains('writeConfig')), isEmpty);
  });

  test('clear errors: missing file, unplugged monitor, Plasma not updating', () async {
    final left = (await setter.targets()).first;
    await expectLater(
      () => setter.apply([Assignment(target: left, imagePath: '/nope.jpg')]),
      throwsA(isA<WallpaperSetterException>().having((e) => e.message, 'message', contains('missing'))),
    );
    const gone = DisplayTarget(id: 'HDMI-A-9', label: 'Old TV', width: 1920, height: 1080);
    await expectLater(
      () => setter.apply([Assignment(target: gone, imagePath: image)]),
      throwsA(isA<WallpaperSetterException>().having((e) => e.message, 'message', contains('no longer connected'))),
    );
    plasma.applyResult = '{"applied":0}';
    await expectLater(
      () => setter.apply([Assignment(target: left, imagePath: image)]),
      throwsA(isA<WallpaperSetterException>()),
    );
  });
}
