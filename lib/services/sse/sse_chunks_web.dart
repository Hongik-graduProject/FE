// 웹: XHR 의 progress 이벤트마다 늘어난 responseText 만 잘라 흘린다.
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Stream<String> sseChunks(Uri uri, Map<String, String> headers) {
  final xhr = web.XMLHttpRequest();
  final out = StreamController<String>();
  var seen = 0;

  void flush() {
    final text = xhr.responseText;
    if (text.length > seen) {
      out.add(text.substring(seen));
      seen = text.length;
    }
  }

  out.onListen = () {
    xhr.open('GET', uri.toString());
    headers.forEach((k, v) => xhr.setRequestHeader(k, v));
    xhr.setRequestHeader('Accept', 'text/event-stream');
    xhr.addEventListener('progress', ((web.Event _) => flush()).toJS);
    xhr.addEventListener(
        'load',
        ((web.Event _) {
          if (xhr.status != 200) {
            out.addError(StateError('SSE HTTP ${xhr.status}'));
          } else {
            flush();
          }
          out.close();
        }).toJS);
    xhr.addEventListener(
        'error',
        ((web.Event _) {
          out.addError(StateError('SSE network error'));
          out.close();
        }).toJS);
    xhr.send();
  };
  out.onCancel = () => xhr.abort();
  return out.stream;
}
