import 'package:disclosure_app/services/sse/sse_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseSse joins split chunks, drops comments, keeps event names', () async {
    final events = await parseSse(Stream.fromIterable([
      ':ping\n\nevent:disclo',
      'sure\ndata:{"a":1}\n\n',
      'event: report\r\ndata: {"b":2}\r\n\r\n',
      'data:x\n', // 빈 줄이 없으면 아직 완성되지 않은 이벤트
    ])).toList();
    expect(events, [
      (event: 'disclosure', data: '{"a":1}'),
      (event: 'report', data: '{"b":2}'),
    ]);
  });
}
