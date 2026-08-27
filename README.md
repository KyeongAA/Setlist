# Setlist

> 공연장에서 들려오는 음악을 인식해 셋리스트로 기록하고, Spotify 플레이리스트로 내보내는 iOS 앱


## 소개

공연이 끝난 뒤 기억에 의존해 곡 목록을 다시 찾지 않아도 되도록, 공연 중 재생되는 음악을 실시간으로 인식하고 순서대로 기록합니다.

인식이 끝난 셋리스트는 공연별로 저장하고 수정할 수 있으며, 연결된 Spotify 계정의 비공개 플레이리스트로 내보낼 수 있습니다.


## 화면 흐름

1. 홈에서 새로운 공연 인식을 시작합니다.
2. 음악을 인식하며 곡을 셋리스트에 자동으로 추가합니다.
3. 필요한 경우 인식을 일시정지하거나 곡을 직접 검색해 추가합니다.
4. 공연 인식을 종료하고 공연명, 설명, 포스터와 곡 순서를 정리합니다.
5. 완성된 공연을 저장하거나 Spotify 플레이리스트로 내보냅니다.

## Screenshots

> 홈, 인식 중, 공연 완료, 상세 화면, Live Activity 스크린샷 추가 예정

## 기술 스택

- Swift
- SwiftUI
- SwiftData
- ShazamKit
- AVFAudio
- ActivityKit
- WidgetKit
- App Intents
- PhotosUI
- AuthenticationServices
- Spotify Web API


## 실행 환경

- Xcode 26.6
- iOS 26.5 이상
- 실제 음악 인식 테스트를 위한 iPhone
- Apple Developer 서명이 필요한 기능
  - ShazamKit
  - Background Audio
  - Live Activities

Dynamic Island는 지원 기기에서만 표시됩니다. 지원하지 않는 기기에서는 잠금화면 Live Activity를 사용할 수 있습니다.


### Spotify Development Mode 제한

현재 Spotify Development Mode에서는 앱 소유자가 Premium 계정을 사용해야 하며, Dashboard Allowlist에 등록한 최대 5명의 사용자만 Web API를 사용할 수 있습니다.

따라서 현재 Spotify 내보내기 기능은 개인 사용 및 제한된 개발 테스트를 목적으로 합니다.

자세한 내용은 [Spotify Quota Modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes)를 참고하세요.

## 권한과 데이터

- 마이크: 공연 중 재생되는 음악 인식
- 사진 보관함: 공연 포스터 선택
- Background Audio: 앱 전환과 화면 잠금 중 음악 인식 유지
- Live Activities: Dynamic Island와 잠금화면에 인식 상태 표시
- Keychain: Spotify 인증 토큰 저장
- SwiftData: 공연, 곡, 인식 구간 및 포스터 데이터 저장

모든 공연 데이터는 현재 사용자의 기기에 저장됩니다.

## 현재 제한 사항

- 음악 인식 세션은 최대 8시간을 기준으로 동작합니다.
- ShazamKit의 인식 결과는 주변 소음과 음원 상태에 따라 달라질 수 있습니다.
- Spotify 기능은 Development Mode Allowlist 제한을 받습니다.
- Live Activity의 표시와 전환 시점은 최종적으로 iOS가 결정합니다.
- 자동화 테스트와 화면별 ViewModel 분리는 아직 진행 전입니다.

## 향후 개선

- 화면별 ViewModel 분리
- 단위 테스트 및 UI 테스트 추가
- Spotify 외 음악 플랫폼 내보내기 검토
- 앱 이름과 아이콘 최종 확정

