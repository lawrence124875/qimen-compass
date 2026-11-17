import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/chart_board.dart';
import '../../compass/compass_math.dart';
import '../../engine/engine.dart' hide Element, palaceBearing;
import '../../l10n/l10n.dart';
import 'heading_tracker.dart';
import 'house_geometry.dart';
import 'house_model.dart';
import 'house_widgets.dart';
import 'mark_rooms_page.dart';
import 'plan_corners_page.dart';
import 'plan_editor_page.dart';

/// 疊加的盤（HANDOFF §6）：時盤（現在或指定時間）、年盤、月盤（看格局）、宅命盤。
enum HouseOverlay { now, pick, year, month, house }

/// 宅盤九宮（HANDOFF §6）：三種輸入（站中心點標記、拍平面圖、手繪）＋坐向＋疊盤。
class HousePage extends StatefulWidget {
  const HousePage({super.key});

  @override
  State<HousePage> createState() => _HousePageState();
}

class _HousePageState extends State<HousePage> {
  static const _engine = ShiJiaEngine();

  House? _house;
  HouseOverlay _overlay = HouseOverlay.now;
  DateTime _picked = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 宅盤內共用方位：在門口鎖定後，走到中心點標記仍維持鎖定。
    HeadingTracker.instance.acquire();
    _load();
  }

  @override
  void dispose() {
    HeadingTracker.instance.release();
    super.dispose();
  }

  Future<void> _load() async {
    final h = await HouseStore.load();
    if (!mounted) return;
    setState(() => _house = h);
    if (!await HouseStore.introSeen() && mounted) {
      await HouseStore.setIntroSeen();
      if (mounted) await showHouseIntro(context);
    }
  }

  Future<void> _save() async {
    setState(() {});
    final h = _house;
    if (h != null) await HouseStore.save(h);
  }

  /// 依選擇的疊盤起局；引擎尚不支援的盤（年、月、日）回傳 null。
  QimenChart? _try(DateTime t, PanUnit unit) {
    try {
      return _engine.compute(t, settings: TimeSettings(utcOffset: t.timeZoneOffset), unit: unit);
    } on UnsupportedError {
      return null;
    }
  }

  (QimenChart?, String) _chart(BuildContext context) {
    final l = context.l10n;
    final now = DateTime.now();
    String fmt(DateTime t, {bool time = true}) {
      String two(int n) => n.toString().padLeft(2, '0');
      final d = '${t.year}-${two(t.month)}-${two(t.day)}';
      return time ? '$d ${two(t.hour)}:${two(t.minute)}' : d;
    }

    switch (_overlay) {
      case HouseOverlay.now:
        return (_try(now, PanUnit.hour), l.houseOverlayHourAt(fmt(now)));
      case HouseOverlay.pick:
        return (_try(_picked, PanUnit.hour), l.houseOverlayHourAt(fmt(_picked)));
      case HouseOverlay.year:
        return (_try(now, PanUnit.year), l.houseOverlayYear);
      case HouseOverlay.month:
        return (_try(now, PanUnit.month), l.houseOverlayMonth);
      case HouseOverlay.house:
        final mi = _house?.moveIn;
        if (mi == null) return (_try(now, PanUnit.year), l.houseFateNoDate);
        if (_house!.moveInHasTime) return (_try(mi, PanUnit.hour), l.houseFateHour(fmt(mi)));
        return (_try(DateTime(mi.year, mi.month, mi.day, 12), PanUnit.day), l.houseFateDay(fmt(mi, time: false)));
    }
  }

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _picked,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_picked));
    if (!mounted) return;
    setState(() {
      _picked = DateTime(d.year, d.month, d.day, t?.hour ?? 12, t?.minute ?? 0);
      _overlay = HouseOverlay.pick;
    });
  }

  Future<bool> _confirmReplace() async {
    if (_house?.plan == null) return true;
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.houseReplacePlan),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.houseCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.houseOk)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deleteOldImage() async {
    final old = _house?.plan?.imagePath;
    if (old == null) return;
    try {
      await File(old).delete();
    } catch (_) {}
  }

  Future<void> _photo(ImageSource source) async {
    if (!await _confirmReplace() || !mounted) return;
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 88);
    } catch (_) {
      if (mounted) _snack(context.l10n.housePhotoFailed);
      return;
    }
    if (x == null || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/house_plan_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(path);
    final size = await imageSizeOf(path);
    if (!mounted) return;
    const init = [Offset(0.08, 0.08), Offset(0.92, 0.08), Offset(0.92, 0.92), Offset(0.08, 0.92)];
    final corners = await Navigator.of(context).push<List<Offset>>(
      MaterialPageRoute(builder: (_) => PlanCornersPage(imagePath: path, corners: init, imageSize: size)),
    );
    if (corners == null) {
      try {
        await File(path).delete();
      } catch (_) {}
      return;
    }
    await _deleteOldImage();
    _house!.plan = FloorPlan(
      imagePath: path,
      imageW: size.width,
      imageH: size.height,
      corners: corners,
      aspect: estimateAspect([for (final c in corners) Offset(c.dx * size.width, c.dy * size.height)]),
    );
    await _save();
    if (mounted) await _openPlan();
  }

  Future<void> _sketch() async {
    if (!await _confirmReplace() || !mounted) return;
    await _deleteOldImage();
    _house!.plan = FloorPlan();
    await _save();
    if (mounted) await _openPlan();
  }

  Future<void> _openPlan() async {
    final plan = _house?.plan;
    if (plan == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlanEditorPage(plan: plan, chart: _chart(context).$1, onChanged: () => HouseStore.save(_house!)),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _openMark() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MarkRoomsPage(house: _house!, chart: _chart(context).$1),
    ));
    if (mounted) setState(() {});
  }

  void _snack(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s)));

  Future<void> _addPlan() async {
    final l = context.l10n;
    final src = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(l.houseFromCamera), onTap: () => Navigator.pop(context, 0)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(l.houseFromGallery), onTap: () => Navigator.pop(context, 1)),
        ]),
      ),
    );
    if (src == null) return;
    await _photo(src == 0 ? ImageSource.camera : ImageSource.gallery);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final h = _house;
    return Scaffold(
      appBar: AppBar(title: Text(l.houseTitle), actions: [
        IconButton(icon: const Icon(Icons.info_outline), tooltip: l.houseIntroTitle, onPressed: () => showHouseIntro(context)),
      ]),
      body: SafeArea(
        child: h == null ? const Center(child: CircularProgressIndicator()) : _body(context, h),
      ),
    );
  }

  Widget _body(BuildContext context, House h) {
    final l = context.l10n;
    final qm = context.qm;
    final theme = Theme.of(context);
    final (chart, chartTitle) = _chart(context);
    final labels = sectorLabels(context, chart);

    final overlay = Wrap(spacing: 6, runSpacing: 6, children: [
      for (final o in HouseOverlay.values)
        ChoiceChip(
          label: Text(switch (o) {
            HouseOverlay.now => l.houseOverlayNow,
            HouseOverlay.pick => l.houseOverlayPick,
            HouseOverlay.year => l.houseOverlayYear,
            HouseOverlay.month => l.houseOverlayMonth,
            HouseOverlay.house => l.houseOverlayFate,
          }),
          selected: _overlay == o,
          onSelected: (_) => o == HouseOverlay.pick ? _pickTime() : setState(() => _overlay = o),
        ),
    ]);

    Widget diagram;
    if (h.plan != null) {
      diagram = GestureDetector(
        onTap: _openPlan,
        child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 460), child: PlanCanvas(plan: h.plan!, labels: labels)),
      );
    } else if (h.marked.isNotEmpty) {
      diagram = BearingWheel(labels: labels, rooms: [for (final r in h.marked) (r.name, r.bearing)]);
    } else {
      diagram = Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.all(16), child: Text(l.houseEmpty, textAlign: TextAlign.center)),
      );
    }

    final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton.icon(icon: const Icon(Icons.my_location), onPressed: _openMark, label: Text(l.houseMethodMark)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.photo_camera_outlined), onPressed: _addPlan, label: Text(l.houseMethodPhoto))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.grid_on), onPressed: _sketch, label: Text(l.houseMethodSketch))),
      ]),
      if (h.plan != null) TextButton(onPressed: _openPlan, child: Text(l.houseEditPlan)),
    ]);

    final facing = h.facing;
    final facingCard = Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.door_front_door_outlined),
        title: Text(facing == null
            ? l.houseFacingUnset
            : l.houseSitFace(palaceLabel(context, palaceAtBearing(sittingOf(facing))), palaceLabel(context, palaceAtBearing(facing)), '${facing.round()}')),
        subtitle: Text('${_methodName(l, h.sittingMethod)}・${h.moveIn == null ? l.houseMoveInUnset : l.houseMoveInIs(_fmtMoveIn(h))}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _editFacing(h),
      ),
    );

    final rooms = h.roomsByPalace();
    final list = Column(children: [
      for (final p in [...palaceRing, 5]) _PalaceTile(chart: chart, palace: p, rooms: rooms[p] ?? const []),
    ]);

    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
      overlay,
      const SizedBox(height: 6),
      Text(chartTitle, style: theme.textTheme.bodySmall?.copyWith(color: qm.textMuted)),
      if (chart == null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l.houseChartPending, style: theme.textTheme.bodySmall?.copyWith(color: qm.bad)),
        ),
      const SizedBox(height: 8),
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: diagram)),
      const SizedBox(height: 12),
      actions,
      const SizedBox(height: 12),
      facingCard,
      const SizedBox(height: 12),
      list,
      const SizedBox(height: 12),
      Text(l.homeDisclaimer, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: qm.textMuted)),
    ]);
  }

  String _fmtMoveIn(House h) {
    final t = h.moveIn!;
    String two(int n) => n.toString().padLeft(2, '0');
    final d = '${t.year}-${two(t.month)}-${two(t.day)}';
    return h.moveInHasTime ? '$d ${two(t.hour)}:${two(t.minute)}' : d;
  }

  static String _methodName(AppLocalizations l, SittingMethod m) => switch (m) {
        SittingMethod.door => l.houseSitDoor,
        SittingMethod.light => l.houseSitLight,
        SittingMethod.building => l.houseSitBuilding,
        SittingMethod.groundDoor => l.houseSitGround,
      };

  static String _methodHint(AppLocalizations l, SittingMethod m) => switch (m) {
        SittingMethod.door => l.houseSitDoorHint,
        SittingMethod.light => l.houseSitLightHint,
        SittingMethod.building => l.houseSitBuildingHint,
        SittingMethod.groundDoor => l.houseSitGroundHint,
      };

  Future<void> _editFacing(House h) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        final l = context.l10n;
        Future<void> update(void Function() f) async {
          f();
          setSheet(() {});
          await _save();
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text(l.houseFacingTitle, style: serif(Theme.of(context).textTheme.titleLarge)),
              const SizedBox(height: 4),
              Text(l.houseFacingNote, style: TextStyle(color: context.qm.textMuted)),
              RadioGroup<SittingMethod>(
                groupValue: h.sittingMethod,
                onChanged: (v) => v == null ? null : update(() => h.sittingMethod = v),
                child: Column(children: [
                  for (final m in SittingMethod.values)
                    RadioListTile<SittingMethod>(
                      contentPadding: EdgeInsets.zero,
                      value: m,
                      title: Text(_methodName(l, m)),
                      subtitle: Text(_methodHint(l, m)),
                    ),
                ]),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.explore_outlined),
                onPressed: () async {
                  final b = await measureBearing(context, title: l.houseMeasureFacing, hint: l.houseMeasureFacingHint);
                  if (b != null) await update(() => h.facing = b.roundToDouble() % 360);
                },
                label: Text(h.facing == null ? l.houseMeasureFacing : l.houseFacingValue('${h.facing!.round()}')),
              ),
              const Divider(height: 28),
              Text(l.houseMoveInTitle, style: Theme.of(context).textTheme.titleMedium),
              Text(l.houseMoveInNote, style: TextStyle(color: context.qm.textMuted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: h.moveIn ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) await update(() => h.moveIn = DateTime(d.year, d.month, d.day, h.moveIn?.hour ?? 0, h.moveIn?.minute ?? 0));
                  },
                  child: Text(h.moveIn == null ? l.houseMoveInDate : _fmtMoveIn(h)),
                ),
                if (h.moveIn != null)
                  OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(h.moveIn!));
                      if (t != null) {
                        await update(() {
                          h.moveIn = DateTime(h.moveIn!.year, h.moveIn!.month, h.moveIn!.day, t.hour, t.minute);
                          h.moveInHasTime = true;
                        });
                      }
                    },
                    child: Text(l.houseMoveInTime),
                  ),
                if (h.moveIn != null)
                  TextButton(
                    onPressed: () => update(() {
                      h.moveIn = null;
                      h.moveInHasTime = false;
                    }),
                    child: Text(l.houseClear),
                  ),
              ]),
            ]),
          ),
        );
      }),
    );
  }
}

/// 一宮：方位、八門（吉平凶）、九星、八神、標記、房間。
class _PalaceTile extends StatelessWidget {
  const _PalaceTile({required this.chart, required this.palace, required this.rooms});

  final QimenChart? chart;
  final int palace;
  final List<String> rooms;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final theme = Theme.of(context);
    final pc = chart?[palace];
    final door = pc?.door;
    final marks = pc == null ? const <ChartMark>[] : marksOf(pc);
    final parts = [
      if (door != null) '${door.zh}（${l.luck(door.luck)}）',
      if (pc != null && pc.stars.isNotEmpty) starsText(pc.stars),
      if (pc?.god != null) pc!.god!.zh,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: chart == null ? null : () => showPalaceSheet(context, chart!, palace),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 64,
              child: Text(palaceLabel(context, palace), style: serif(theme.textTheme.titleSmall).copyWith(color: qm.primary)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (parts.isNotEmpty)
                  Text.rich(TextSpan(children: [
                    if (door != null)
                      TextSpan(text: parts.first, style: TextStyle(color: qm.luck(door.luck), fontWeight: FontWeight.w600)),
                    TextSpan(text: (door != null ? parts.skip(1) : parts).map((s) => '  $s').join()),
                  ]), style: serif(theme.textTheme.bodyMedium)),
                if (marks.isNotEmpty)
                  Text(marks.map((m) => QimenTerms.markShort(m)).join(' '), style: theme.textTheme.bodySmall?.copyWith(color: qm.bad)),
                Text(rooms.isEmpty ? l.houseNoRoomHere : rooms.join('、'),
                    style: theme.textTheme.bodySmall?.copyWith(color: rooms.isEmpty ? qm.textMuted : qm.text)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 首次進入的 3 頁引導（比照謙卦），右上 ⓘ 可重看。
Future<void> showHouseIntro(BuildContext context) {
  final l = context.l10n;
  final pages = [
    (Icons.explore_outlined, l.houseIntro1Title, l.houseIntro1),
    (Icons.my_location, l.houseIntro2Title, l.houseIntro2),
    (Icons.grid_view, l.houseIntro3Title, l.houseIntro3),
  ];
  final ctrl = PageController();
  var page = 0;
  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => AlertDialog(
        title: Text(l.houseIntroTitle),
        content: SizedBox(
          width: 320,
          height: 260,
          child: PageView(
            controller: ctrl,
            onPageChanged: (i) => set(() => page = i),
            children: [
              for (final (icon, title, body) in pages)
                SingleChildScrollView(
                  child: Column(children: [
                    Icon(icon, size: 48, color: context.qm.primary),
                    const SizedBox(height: 12),
                    Text(title, style: serif(Theme.of(context).textTheme.titleMedium), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(body, textAlign: TextAlign.center),
                  ]),
                ),
            ],
          ),
        ),
        actions: [
          Text('${page + 1} / ${pages.length}'),
          FilledButton(
            onPressed: () => page < pages.length - 1
                ? ctrl.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
                : Navigator.pop(context),
            child: Text(page < pages.length - 1 ? l.houseNext : l.houseOk),
          ),
        ],
      ),
    ),
  ).whenComplete(ctrl.dispose);
}
