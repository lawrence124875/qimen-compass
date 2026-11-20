import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/shared/widgets/ymd_date_picker.dart';

void main() {
  test('parseYmd 接受 yyyy/mm/dd 與常見寫法', () {
    expect(parseYmd('1990/01/01'), DateTime(1990, 1, 1));
    expect(parseYmd('1990/1/2'), DateTime(1990, 1, 2));
    expect(parseYmd('1990-12-31'), DateTime(1990, 12, 31));
    expect(parseYmd('1990.07.15'), DateTime(1990, 7, 15));
    expect(parseYmd('19900101'), DateTime(1990, 1, 1));
    expect(parseYmd('1990年3月4日'), DateTime(1990, 3, 4));
  });

  test('parseYmd 拒絕錯誤日期與 dd/mm/yyyy', () {
    expect(parseYmd('01/01/1990'), isNull);
    expect(parseYmd('1990/02/30'), isNull);
    expect(parseYmd('1990/13/01'), isNull);
    expect(parseYmd(''), isNull);
  });

  test('formatYmd', () {
    expect(formatYmd(DateTime(1990, 1, 1)), '1990/01/01');
  });
}
