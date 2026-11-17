import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

/// Answers commands from a table and records what was run.
class FakeTools {
  FakeTools(this.replies);

  /// "exe arg1 arg2" prefix -> stdout, or null to fail as "not installed".
  final Map<String, String?> replies;
  final run = <String>[];

  Future<ProcessResult> call(String exe, List<String> args) async {
    final line = [exe, ...args].join(' ');
    run.add(line);
    for (final MapEntry(:key, :value) in replies.entries) {
      if (line.startsWith(key)) {
        if (value == null) throw ProcessException(exe, args, 'not found', 2);
        return ProcessResult(0, 0, value, '');
      }
    }
    return ProcessResult(0, 0, '', '');
  }
}

const xrandr = '''
Monitors: 2
 0: +*DP-1 3840/600x2160/340+0+0  DP-1
 1: +HDMI-A-1 2560/600x1440/340+3840+0  HDMI-A-1
''';

Assignment on(DisplayTarget t, String path, [FitMode fit = FitMode.fill]) =>
    Assignment(target: t, imagePath: path, fit: fit);

void main() {
  late Directory temp;
  late String image;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wf_desktops_');
    image = p.join(temp.path, 'my image.jpg');
    await File(image).writeAsString('x');
  });

  tearDown(() => temp.delete(recursive: true));

  test('shared helpers: xrandr parsing and position labels', () {
    final outputs = parseXrandrMonitors(xrandr);
    expect(outputs.map((o) => (o.name, o.width, o.height, o.x, o.primary)), [
      ('DP-1', 3840, 2160, 0, true),
      ('HDMI-A-1', 2560, 1440, 3840, false),
    ]);
    expect(monitorLabels([(x: 1920, y: 0), (x: 0, y: 0)]), ['Right monitor', 'Left monitor']);
    expect(monitorLabels([(x: 0, y: 0), (x: 0, y: 1080)]), ['Top monitor', 'Bottom monitor']);
    expect(monitorTargets(outputs).map((t) => t.label), ['Left monitor (DP-1)', 'Right monitor (HDMI-A-1)']);
  });

  group('GNOME family', () {
    test('GNOME sets light and dark pictures, fit, and the lock screen', () async {
      final tools = FakeTools({'xrandr': xrandr});
      final gnome = GnomeSetter(GnomeFlavour.gnome, runProcess: tools.call);
      final targets = await gnome.targets();
      expect(targets.map((t) => t.id), ['desktop', 'lock']);
      expect(targets.first.width, 3840, reason: 'largest monitor');
      expect((await gnome.capabilities()).perTarget, isFalse);

      await gnome.apply([on(targets[0], image, FitMode.fit), on(targets[1], image)]);

      final uri = Uri.file(image).toString();
      expect(tools.run.where((c) => c.startsWith('gsettings')), [
        'gsettings set org.gnome.desktop.background picture-uri $uri',
        'gsettings set org.gnome.desktop.background picture-uri-dark $uri',
        'gsettings set org.gnome.desktop.background picture-options scaled',
        'gsettings set org.gnome.desktop.screensaver picture-uri $uri',
        'gsettings set org.gnome.desktop.screensaver picture-options zoom',
      ]);
    });

    test('MATE uses a plain path; Cinnamon its own schema; no xrandr is fine', () async {
      final tools = FakeTools({'xrandr': null});
      final mate = GnomeSetter(GnomeFlavour.mate, runProcess: tools.call);
      final targets = await mate.targets();
      expect(targets.single.width, 1920);
      await mate.apply([on(targets.single, image)]);
      expect(tools.run, contains('gsettings set org.mate.background picture-filename $image'));

      final cinnamonTools = FakeTools({'xrandr': xrandr});
      final cinnamon = GnomeSetter(GnomeFlavour.cinnamon, runProcess: cinnamonTools.call);
      await cinnamon.apply([on((await cinnamon.targets()).single, image)]);
      expect(cinnamonTools.run, contains('gsettings set org.cinnamon.desktop.background picture-uri ${Uri.file(image)}'));
    });
  });

  test('Xfce sets every workspace of the chosen monitor, creating image-style if needed', () async {
    const listing = '''
/backdrop/screen0/monitorDP-1/workspace0/last-image
/backdrop/screen0/monitorDP-1/workspace1/last-image
/backdrop/screen0/monitorDP-1/workspace1/image-style
/backdrop/screen0/monitorHDMI-A-1/workspace0/last-image
''';
    final tools = FakeTools({'xfconf-query -c xfce4-desktop -l': listing, 'xrandr': xrandr});
    final xfce = XfceSetter(runProcess: tools.call);
    final targets = await xfce.targets();
    expect(targets.map((t) => t.label), ['Left monitor (DP-1)', 'Right monitor (HDMI-A-1)']);

    tools.run.clear();
    await xfce.apply([on(targets.first, image, FitMode.fit)]);

    final sets = tools.run.where((c) => c.contains(' -p ')).toList();
    expect(sets, [
      'xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorDP-1/workspace0/last-image -s $image',
      'xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorDP-1/workspace0/image-style -n -t int -s 4',
      'xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorDP-1/workspace1/last-image -s $image',
      'xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorDP-1/workspace1/image-style -s 4',
    ]);
  });

  test('Sway: outputs from swaymsg, one bg command per output', () async {
    final outputs = jsonEncode([
      {'name': 'DP-1', 'active': true, 'focused': true, 'rect': {'x': 0, 'y': 0, 'width': 2560, 'height': 1440}, 'current_mode': {'width': 3840, 'height': 2160}, 'transform': 'normal'},
      {'name': 'eDP-1', 'active': true, 'rect': {'x': 2560, 'y': 0, 'width': 1080, 'height': 1920}, 'current_mode': {'width': 1920, 'height': 1080}, 'transform': '90'},
      {'name': 'HDMI-A-1', 'active': false, 'rect': {'x': 0, 'y': 0, 'width': 0, 'height': 0}},
    ]);
    final tools = FakeTools({'swaymsg -t get_outputs': outputs});
    final sway = SwaySetter(runProcess: tools.call);
    final targets = await sway.targets();
    expect(targets.map((t) => (t.id, t.width, t.height, t.isPrimary)), [
      ('DP-1', 3840, 2160, true),
      ('eDP-1', 1080, 1920, false),
    ]);

    await sway.apply([on(targets[1], image, FitMode.centre)]);
    expect(tools.run.last, 'swaymsg output eDP-1 bg $image center');
  });

  group('Hyprland', () {
    final monitors = jsonEncode([
      {'name': 'DP-1', 'width': 3840, 'height': 2160, 'x': 0, 'y': 0, 'transform': 0, 'focused': true},
      {'name': 'DP-2', 'width': 2560, 'height': 1440, 'x': 3840, 'y': 0, 'transform': 1, 'focused': false},
    ]);

    test('uses swww when its daemon answers', () async {
      final tools = FakeTools({'hyprctl monitors': monitors, 'awww': null, 'swww query': ''});
      final hypr = HyprlandSetter(runProcess: tools.call);
      final targets = await hypr.targets();
      expect((targets[1].width, targets[1].height), (1440, 2560), reason: 'rotated');

      await hypr.apply([on(targets[0], image, FitMode.fit)]);
      expect(tools.run.last, 'swww img -o DP-1 --resize fit $image');
    });

    test('falls back to hyprpaper, and explains when neither is running', () async {
      final tools = FakeTools({'hyprctl monitors': monitors, 'awww': null, 'swww': null, 'hyprctl hyprpaper listloaded': ''});
      final hypr = HyprlandSetter(runProcess: tools.call);
      final left = (await hypr.targets()).first;
      await hypr.apply([on(left, image)]);
      expect(tools.run, containsAllInOrder([
        'hyprctl hyprpaper preload $image',
        'hyprctl hyprpaper wallpaper DP-1,$image',
      ]));

      final none = FakeTools({'hyprctl monitors': monitors, 'awww': null, 'swww': null, 'hyprctl hyprpaper': null});
      await expectLater(
        HyprlandSetter(runProcess: none.call).apply([on(left, image)]),
        throwsA(isA<WallpaperSetterException>().having((e) => e.message, 'message', contains('swww-daemon or hyprpaper'))),
      );
    });
  });

  test('feh keeps the other monitor\'s image from ~/.fehbg', () async {
    final fehbg = p.join(temp.path, '.fehbg');
    await File(fehbg).writeAsString("#!/bin/sh\nfeh --no-fehbg --bg-fill '/old/left.jpg' '/old/it'\\''s right.png' \n");
    expect(FehSetter.parseFehbg(await File(fehbg).readAsString()), ['/old/left.jpg', "/old/it's right.png"]);

    final tools = FakeTools({'xrandr': xrandr});
    final feh = FehSetter(runProcess: tools.call, fehbgPath: fehbg);
    final targets = await feh.targets();
    await feh.apply([on(targets[0], image, FitMode.fit)]);

    expect(tools.run.last, "feh --bg-max $image /old/it's right.png");
  });

  test('missing tools give a clear error', () async {
    final tools = FakeTools({'gsettings': null, 'xrandr': xrandr});
    final gnome = GnomeSetter(GnomeFlavour.gnome, runProcess: tools.call);
    await expectLater(
      gnome.apply([on((await gnome.targets()).first, image)]),
      throwsA(isA<WallpaperSetterException>().having((e) => e.message, 'message', contains('gsettings'))),
    );
  });
}
