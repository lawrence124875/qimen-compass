import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'free_limits.dart';

/// 今天還能不能使用。
enum UsageAllowance {
  /// 免費次數還有（或是訂閱戶）。
  free,

  /// 免費次數用完，但還能看獎勵廣告換一次。
  needsReward,

  /// 免費與獎勵次數都用完，明天再來或訂閱。
  exhausted,
}

/// 一次使用的紀錄結果（[UsageQuota.recordUse]）。
class UsageRecord {
  const UsageRecord({required this.firstEver, required this.dailyFree});

  /// 這支手機第一次使用（統計 `qm_first_use`）。
  final bool firstEver;

  /// 用的是今天的免費次數（不是獎勵換來的、也不是訂閱戶）：解讀前要播插頁（HANDOFF §2.1）。
  final bool dailyFree;
}

/// 每日使用次數（本機計數，跨日自動歸零；以手機當地日期為準）。
/// 計數只存在本機檔案，不上傳；重裝 App 會歸零，這是可接受的寬鬆。
class UsageQuota {
  UsageQuota({required this.limits, QuotaStorage? storage, DateTime Function()? clock})
      : _storage = storage ?? FileQuotaStorage(),
        _clock = clock ?? DateTime.now;

  FreeLimits limits;
  final QuotaStorage _storage;
  final DateTime Function() _clock;

  String _day = '';
  int _used = 0; // 今天已使用次數（含用獎勵換來的）
  int _rewarded = 0; // 今天看獎勵廣告換到的次數
  bool _everCast = false; // 曾經用過（不隨日期歸零）
  bool _loaded = false;

  String _today() {
    final n = _clock();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _ensure() async {
    if (!_loaded) {
      final m = await _storage.read();
      _day = m['day'] as String? ?? '';
      _used = (m['used'] as num?)?.toInt() ?? 0;
      _rewarded = (m['rewarded'] as num?)?.toInt() ?? 0;
      // 舊版存檔沒有 ever，但有 day＝以前用過（升級的使用者不算第一次）
      _everCast = m['ever'] == true || m.containsKey('day');
      _loaded = true;
    }
    final today = _today();
    if (_day != today) {
      _day = today;
      _used = 0;
      _rewarded = 0;
    }
  }

  Future<void> _persist() =>
      _storage.write({'day': _day, 'used': _used, 'rewarded': _rewarded, 'ever': _everCast});

  /// 可用次數＝免費次數＋今天看廣告換到的次數。
  Future<UsageAllowance> check() async {
    await _ensure();
    if (_used < limits.travelPerDay + _rewarded) return UsageAllowance.free;
    return _rewarded < limits.rewardedPerDay ? UsageAllowance.needsReward : UsageAllowance.exhausted;
  }

  /// 今天用過了嗎（訂閱戶不扣次數，另記使用日期）。
  Future<bool> usedToday() async {
    await _ensure();
    return _used > 0 || _castDay == _day;
  }

  String _castDay = ''; // 訂閱戶使用的日期（只在記憶體，重開 App 會忘記，可接受）

  /// 今天剩幾次免費（不含獎勵）；顯示用。
  Future<int> freeLeft() async {
    await _ensure();
    final left = limits.travelPerDay + _rewarded - _used;
    return left < 0 ? 0 : left;
  }

  /// 使用成功時呼叫一次。訂閱戶傳 [counted] = false：不扣次數，只記「曾經用過」。
  Future<UsageRecord> recordUse({bool counted = true}) async {
    await _ensure();
    final first = !_everCast;
    _everCast = true;
    _castDay = _day;
    final dailyFree = counted && _used < limits.travelPerDay;
    if (counted) _used++;
    if (counted || first) await _persist();
    return UsageRecord(firstEver: first, dailyFree: dailyFree);
  }

  /// 使用者看完獎勵廣告：多一次使用。
  Future<void> grantReward() async {
    await _ensure();
    _rewarded++;
    await _persist();
  }
}

abstract class QuotaStorage {
  Future<Map<String, Object?>> read();
  Future<void> write(Map<String, Object?> data);
}

class MemoryQuotaStorage implements QuotaStorage {
  Map<String, Object?> data = {};

  @override
  Future<Map<String, Object?>> read() async => {...data};

  @override
  Future<void> write(Map<String, Object?> d) async => data = {...d};
}

/// 存在 App 文件資料夾的 `quota.json`（不需權限；出行訣存 `travel_quota.json`。
class FileQuotaStorage implements QuotaStorage {
  FileQuotaStorage({this.fileName = 'quota.json'});

  final String fileName;

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/$fileName');

  @override
  Future<Map<String, Object?>> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return (jsonDecode(await f.readAsString()) as Map).cast<String, Object?>();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> write(Map<String, Object?> data) async {
    try {
      await (await _file()).writeAsString(jsonEncode(data));
    } catch (_) {
      // 寫不進去只會讓計數寬鬆，不影響使用
    }
  }
}
