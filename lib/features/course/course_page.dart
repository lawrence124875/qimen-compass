import 'package:flutter/material.dart';

import '../../app/main_shell.dart';
import '../../app/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../travel/travel_page.dart';
import 'course.dart';

/// 課程目錄：課程名稱、簡介、各課（免費標記、已讀、鎖定）。
class CoursePage extends StatefulWidget {
  const CoursePage({super.key});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  late final Future<Course> _course = CourseRepository.load(L10n.language);

  @override
  void initState() {
    super.initState();
    CourseProgress.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.courseTitle)),
      body: FutureBuilder<Course>(
        future: _course,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final course = snap.data!;
          if (course.isEmpty) return Center(child: Text(l.courseEmpty));
          return ListenableBuilder(
            listenable: Listenable.merge([CourseProgress.instance, CourseAccess.premium]),
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(course.title, style: serif(Theme.of(context).textTheme.headlineSmall)),
                const SizedBox(height: 8),
                Text(course.intro, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.qm.textMuted)),
                const SizedBox(height: 8),
                Text(l.courseProgress(_doneIn(course), course.lessons.length),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.qm.accent)),
                const SizedBox(height: 12),
                for (var i = 0; i < course.lessons.length; i++) _LessonTile(course: course, index: i),
              ],
            ),
          );
        },
      ),
    );
  }

  int _doneIn(Course c) => c.lessons.where((x) => CourseProgress.instance.isDone(x.id)).length;
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.course, required this.index});

  final Course course;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lesson = course.lessons[index];
    final unlocked = CourseAccess.unlocked(lesson);
    final done = CourseProgress.instance.isDone(lesson.id);
    final muted = context.qm.textMuted;
    final meta = [
      l.courseLesson(index + 1),
      l.courseMinutes(lesson.minutes),
      if (lesson.free && CourseAccess.paywallEnabled) l.courseFree,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(lesson.title, style: serif(Theme.of(context).textTheme.titleMedium)),
        subtitle: Text('$meta\n${lesson.summary}', style: TextStyle(color: muted)),
        isThreeLine: true,
        trailing: Icon(
          !unlocked ? Icons.lock_outline : (done ? Icons.check_circle : Icons.chevron_right),
          color: done && unlocked ? context.qm.good : muted,
        ),
        onTap: () {
          if (!unlocked) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l.courseLocked)));
            return;
          }
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LessonPage(course: course, index: index)));
        },
      ),
    );
  }
}

/// 單課內容：段落、重點、課末按鈕（開啟對應功能）與下一課。
class LessonPage extends StatelessWidget {
  const LessonPage({super.key, required this.course, required this.index});

  final Course course;
  final int index;

  Lesson get lesson => course.lessons[index];

  void _openAction(BuildContext context, CourseActionType type) {
    CourseProgress.instance.markDone(lesson.id);
    final nav = Navigator.of(context);
    switch (type) {
      case CourseActionType.chart:
        nav.popUntil((r) => r.isFirst);
        MainShell.select(MainTab.chart);
      case CourseActionType.travel:
        nav.push(MaterialPageRoute<void>(builder: (_) => const TravelPage()));
      case CourseActionType.compass:
        nav.popUntil((r) => r.isFirst);
        MainShell.select(MainTab.compass);
      case CourseActionType.zeshi:
        nav.popUntil((r) => r.isFirst);
        MainShell.select(MainTab.zeshi);
    }
  }

  void _next(BuildContext context) {
    CourseProgress.instance.markDone(lesson.id);
    final nav = Navigator.of(context);
    final n = index + 1;
    if (n < course.lessons.length && CourseAccess.unlocked(course.lessons[n])) {
      nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => LessonPage(course: course, index: n)));
    } else {
      nav.pop();
      if (n < course.lessons.length) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.courseLocked)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final qm = context.qm;
    final action = lesson.action;
    final hasNext = index + 1 < course.lessons.length;
    return Scaffold(
      appBar: AppBar(title: Text(l.courseLesson(index + 1))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(lesson.title, style: serif(t.headlineSmall)),
                const SizedBox(height: 4),
                Text(l.courseMinutes(lesson.minutes), style: t.labelMedium?.copyWith(color: qm.textMuted)),
                for (final s in lesson.sections) ...[
                  const SizedBox(height: 20),
                  if (s.heading.isNotEmpty) Text(s.heading, style: serif(t.titleMedium).copyWith(color: qm.accent)),
                  for (final p in s.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(p, style: t.bodyLarge?.copyWith(height: 1.7)),
                    ),
                ],
                if (lesson.takeaways.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.courseTakeaways, style: serif(t.titleSmall).copyWith(color: qm.accent)),
                          for (final k in lesson.takeaways)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(end: 8, top: 2),
                                    child: Icon(Icons.check, size: 16, color: qm.accent),
                                  ),
                                  Expanded(child: Text(k, style: t.bodyMedium)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (action != null)
                  FilledButton(onPressed: () => _openAction(context, action.type), child: Text(action.label)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _next(context),
                  child: Text(hasNext ? l.courseNext : l.courseFinish),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
