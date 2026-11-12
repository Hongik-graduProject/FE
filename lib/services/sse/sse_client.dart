// lib/services/sse/sse_client.dart — Authorization 헤더를 실을 수 있는 최소 SSE 클라이언트.
// 브라우저 EventSource 는 헤더를 못 넣으므로 플랫폼별로 원문 청크를 받고 파싱만 공유한다.
import 'sse_chunks_io.dart' if (dart.library.js_interop) 'sse_chunks_web.dart'
    as chunks;

typedef SseEvent = ({String event, String data});

Stream<SseEvent> openSse(Uri uri, Map<String, String> headers) =>
    parseSse(chunks.sseChunks(uri, headers));

/// text/event-stream 청크를 이벤트로 바꾼다. 주석(`:ping`)은 버린다.
Stream<SseEvent> parseSse(Stream<String> source) async* {
  var buf = '';
  var event = 'message';
  final data = StringBuffer();
  await for (final chunk in source) {
    buf += chunk;
    int i;
    while ((i = buf.indexOf('\n')) >= 0) {
      var line = buf.substring(0, i);
      buf = buf.substring(i + 1);
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.isEmpty) {
        if (data.isNotEmpty) yield (event: event, data: data.toString());
        event = 'message';
        data.clear();
      } else if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        if (data.isNotEmpty) data.write('\n');
        data.write(line.substring(5).trimLeft());
      }
    }
  }
}
