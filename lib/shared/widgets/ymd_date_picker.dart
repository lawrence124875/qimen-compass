import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 日期選擇（取代 showDatePicker 的輸入模式）：系統輸入框的格式提示依地區而變（例如 dd/mm/yyyy），
/// 與實際解析格式不一致會顯示「格式錯誤」。這裡一律用 yyyy/mm/dd，也接受 - . 分隔或 8 位數字；
/// 右上角可切換月曆。
Future<DateTime?> showYmdDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  bool calendarFirst = false,
}) =>
    showDialog<DateTime>(
      context: context,
      builder: (_) => _YmdDialog(
        initial: _clamp(initialDate, firstDate, lastDate),
        first: firstDate,
        last: lastDate,
        helpText: helpText,
        calendarFirst: calendarFirst,
      ),
    );

DateTime _clamp(DateTime d, DateTime a, DateTime b) => d.isBefore(a) ? a : (d.isAfter(b) ? b : d);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String formatYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// 解析 yyyy/mm/dd（也接受 - . 空白分隔、19900101）；無效回傳 null。
DateTime? parseYmd(String s) {
  final t = s.trim();
  int y, m, d;
  final digits = RegExp(r'^\d{8}$');
  if (digits.hasMatch(t)) {
    y = int.parse(t.substring(0, 4));
    m = int.parse(t.substring(4, 6));
    d = int.parse(t.substring(6, 8));
  } else {
    final p = RegExp(r'^(\d{4})\s*[/\-.年\s]\s*(\d{1,2})\s*[/\-.月\s]\s*(\d{1,2})\s*日?$').firstMatch(t);
    if (p == null) return null;
    y = int.parse(p.group(1)!);
    m = int.parse(p.group(2)!);
    d = int.parse(p.group(3)!);
  }
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final r = DateTime(y, m, d);
  return r.month == m && r.day == d ? r : null;
}

/// 打字時自動補斜線：19900101 → 1990/01/01。
class _YmdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // 刪除時不自動補，避免卡在斜線上
    if (newValue.text.length < oldValue.text.length) return newValue;
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != newValue.text.length) return newValue; // 使用者自己打分隔符號，保留原樣
    final b = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 4 || i == 6) b.write('/');
      b.write(digits[i]);
    }
    final s = b.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

class _YmdDialog extends StatefulWidget {
  const _YmdDialog({required this.initial, required this.first, required this.last, this.helpText, required this.calendarFirst});

  final DateTime initial, first, last;
  final String? helpText;
  final bool calendarFirst;

  @override
  State<_YmdDialog> createState() => _YmdDialogState();
}

class _YmdDialogState extends State<_YmdDialog> {
  late final _ctrl = TextEditingController(text: formatYmd(widget.initial));
  late DateTime _value = _day(widget.initial);
  late bool _calendar = widget.calendarFirst;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _inRange(DateTime d) => !d.isBefore(_day(widget.first)) && !d.isAfter(_day(widget.last));

  void _submit() {
    final ml = MaterialLocalizations.of(context);
    if (_calendar) {
      Navigator.of(context).pop(_value);
      return;
    }
    final d = parseYmd(_ctrl.text);
    if (d == null) {
      setState(() => _error = ml.invalidDateFormatLabel);
      return;
    }
    if (!_inRange(d)) {
      setState(() => _error = ml.dateOutOfRangeLabel);
      return;
    }
    Navigator.of(context).pop(d);
  }

  void _toggle() {
    setState(() {
      if (!_calendar) {
        final d = parseYmd(_ctrl.text);
        if (d != null && _inRange(d)) _value = d;
      } else {
        _ctrl.text = formatYmd(_value);
      }
      _error = null;
      _calendar = !_calendar;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ml = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      title: Row(children: [
        Expanded(child: Text(widget.helpText ?? ml.datePickerHelpText, style: theme.textTheme.titleMedium)),
        IconButton(
          tooltip: _calendar ? ml.inputDateModeButtonLabel : ml.calendarModeButtonLabel,
          icon: Icon(_calendar ? Icons.edit_outlined : Icons.calendar_today_outlined),
          onPressed: _toggle,
        ),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: _calendar
          ? SizedBox(
              width: 320,
              height: 340,
              child: CalendarDatePicker(
                initialDate: _value,
                firstDate: widget.first,
                lastDate: widget.last,
                onDateChanged: (d) => _value = d,
              ),
            )
          : SizedBox(
              width: 320,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/\-. ]')), _YmdFormatter()],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: ml.dateInputLabel,
                  hintText: 'yyyy/mm/dd',
                  helperText: 'yyyy/mm/dd',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(ml.cancelButtonLabel)),
        FilledButton(onPressed: _submit, child: Text(ml.okButtonLabel)),
      ],
    );
  }
}
