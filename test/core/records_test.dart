import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/core/monetization/free_limits.dart';
import 'package:qimen_compass/core/monetization/usage_quota.dart';
import 'package:qimen_compass/core/records/record_store.dart';

void main() {
  test('紀錄備份往返、略過壞資料、拒絕別的格式', () {
    final r = QimenRecord(
      id: '1',
      createdAt: DateTime(2026, 11, 17, 9),
      kind: RecordKind.travel,
      chartAt: DateTime(2026, 11, 17, 11),
      summary: '陽遁三局',
      title: '面試',
      outcome: RecordOutcome.partly,
    );
    final text = RecordBackup.encode([r], DateTime(2026, 11, 18));
    final back = RecordBackup.decode(text).single;
    expect(back.title, '面試');
    expect(back.kind, RecordKind.travel);
    expect(back.outcome, RecordOutcome.partly);
    expect(back.chartAt, r.chartAt);
    expect(RecordBackup.decode('{"format":"qimen-records","records":[{"id":1}]}'), isEmpty);
    expect(() => RecordBackup.decode('{"format":"qiangua-journal","entries":[]}'), throwsFormatException);
  });

  test('還原只加入沒有的 id', () async {
    final s = MemoryRecordStore();
    final a = QimenRecord(id: 'a', createdAt: DateTime(2026), kind: RecordKind.chart, chartAt: DateTime(2026), summary: 'x');
    await s.save(a);
    expect(await s.addMissing([a, a.copyWith(title: 'y'), QimenRecord.tryFromJson({...a.toJson(), 'id': 'b'})!]), 1);
    expect((await s.all()).length, 2);
  });

  test('出行訣每日額度：1 次免費＋1 次獎勵，跨日歸零', () async {
    var now = DateTime(2026, 11, 17, 10);
    final q = UsageQuota(limits: const FreeLimits(), storage: MemoryQuotaStorage(), clock: () => now);
    expect(await q.check(), UsageAllowance.free);
    expect((await q.recordUse()).dailyFree, isTrue);
    expect(await q.check(), UsageAllowance.needsReward);
    await q.grantReward();
    expect(await q.check(), UsageAllowance.free);
    await q.recordUse();
    expect(await q.check(), UsageAllowance.exhausted);
    now = DateTime(2026, 11, 18, 8);
    expect(await q.check(), UsageAllowance.free);
  });

  test('遠端數值不合理時用預設', () {
    final l = FreeLimits.from((k, d) => k == 'qm_free_travel_per_day' ? 0 : (k == 'qm_free_record_max' ? 50 : d));
    expect(l.travelPerDay, 1);
    expect(l.recordMax, 50);
  });
}
