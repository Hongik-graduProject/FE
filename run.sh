#!/usr/bin/env bash
# Flutter 웹 앱을 항상 같은 포트(3000)로 띄운다.
# 기본 `flutter run`은 매번 임의 포트를 골라 주소가 바뀌므로 여기서 고정한다.
# (BE는 8080 고정 — 그 포트는 피한다.)
set -euo pipefail
cd "$(dirname "$0")"
exec flutter run -d chrome --web-port=3000 --web-hostname=localhost "$@"
