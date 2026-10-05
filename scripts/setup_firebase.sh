#!/usr/bin/env bash
# Firebase 클라이언트 설정 파일을 앱 프로젝트로 복사한다(레포에는 커밋하지 않는다).
# 사용: scripts/setup_firebase.sh [설정 파일 디렉터리, 기본 ~/.secrets/phodam]
set -euo pipefail

SRC="${1:-$HOME/.secrets/phodam}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

copy() {
  local from="$SRC/$1" to="$ROOT/$2"
  if [[ ! -f "$from" ]]; then
    echo "없음: $from" >&2
    exit 1
  fi
  cp "$from" "$to"
  echo "복사: $1 -> $2"
}

copy GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
copy google-services.json android/app/google-services.json

if ! grep -q CLIENT_ID "$ROOT/ios/Runner/GoogleService-Info.plist"; then
  echo "참고: GoogleService-Info.plist 에 OAuth 클라이언트(CLIENT_ID)가 없어 Google 로그인은 아직 설정되지 않았다." >&2
fi
