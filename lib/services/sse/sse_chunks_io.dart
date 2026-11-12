// 모바일·데스크톱: dart:io 로 응답 본문을 그대로 흘린다.
import 'dart:convert';
import 'dart:io';

Stream<String> sseChunks(Uri uri, Map<String, String> headers) async* {
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    headers.forEach(req.headers.set);
    req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    final res = await req.close();
    if (res.statusCode != 200) {
      throw HttpException('SSE HTTP ${res.statusCode}', uri: uri);
    }
    yield* res.transform(utf8.decoder);
  } finally {
    client.close(force: true);
  }
}
