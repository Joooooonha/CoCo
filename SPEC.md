# CoCo - Product Specification

> 다른 러너의 코스를 경로와 맥락 정보로 미리 확인하고, 나에게 맞는 러닝 코스를 선택하는 iOS 앱

## 0. 문서 정보

| 항목 | 기준 |
|---|---|
| 제품명 | CoCo |
| 제품 버전 | MVP v0.1 구현 중 |
| 다음 버전 | V2 v0.2: TestFlight, Sign in with Apple, 공개 API와 운영 자동화 |
| 디자인 원본 | [Apple AI Playground](https://www.figma.com/make/XyGem2zz4Yhecbn145qW6q/Apple-AI-Playground?t=Rb5BipBGwPT9EY0D-1) |
| 디자인 가이드 | `HIGAgentSkills-main`의 Apple HIG OS 27 업데이트판 |
| iOS 최소 버전 | iOS 26.2, 현재 Xcode 프로젝트 설정과 일치 |
| MVP 배포 대상 | 개발자 본인의 iPhone, Xcode 서명 설치 |
| V2 배포 대상 | TestFlight 내부 테스터 후 외부 테스터 |
| 공개 App Store 배포 | V2 범위 아님 |

### 버전 원칙

- HIG의 OS 27은 디자인 참고 기준이고 iOS 최소 버전과 같은 개념이 아니다.
- 앱 코드는 iOS 26.2에서 사용할 수 있는 API로 작성한다.
- OS 27 전용 API나 표현은 SDK와 실기기 지원을 확인하고 별도 범위로 채택한다.
- 최소 버전을 바꾸기 전 실제 테스트 기기의 iOS 버전을 확인한다.

---

## 1. 제품 목표

### 문제

러닝 코스의 선만 보면 실제로 달리기 좋은지 판단하기 어렵다. 러너는 달리기 전에 경관, 주의 구간, 편의시설과 난이도를 함께 보고 싶다.

### 핵심 가치

CoCo의 핵심은 코스를 많이 검색하는 것이 아니라, 선택한 코스를 달리기 전에 구체적으로 판단하게 하는 것이다.

### 대상 사용자

- 익숙하지 않은 지역에서 달릴 코스를 찾는 러너
- 반복하던 코스 대신 새로운 코스를 시도하려는 러너
- 자신의 코스와 코스 위 맥락을 다른 사용자에게 공유하려는 러너

### 성공 신호

- 사용자가 코스를 선택하면 경로와 요소를 한 화면에서 이해할 수 있다.
- 마음에 드는 코스를 스크랩하고 다시 찾을 수 있다.
- 사용자가 직접 계획한 코스와 요소를 등록할 수 있다.
- 코스에 대한 짧은 반응을 남기고 다른 사용자의 반응을 확인할 수 있다.

---

## 2. 핵심 용어

| 용어 | 의미 |
|---|---|
| 코스 | 러닝 경로, 기본 정보, 작성자, 요소를 묶은 공유 단위 |
| 경로 지점 | 코스 선을 구성하는 순서가 있는 위도·경도 좌표 |
| 코스 요소 | 경로 위 특정 위치에 작성자가 남긴 경관·주의·편의 정보 |
| 스크랩 | 사용자가 다시 보고 싶은 코스를 개인 보관함에 저장한 상태 |
| 반응 | 코스 전체에 대해 사용자가 남기는 정해진 피드백 |
| 게스트 사용자 | 별도 로그인 화면 없이 기기에서 발급받은 계정 |
| Apple 사용자 | Sign in with Apple로 복구 가능한 계정으로 전환한 사용자 |

코스 요소와 반응은 다르다. 요소는 경로 위 좌표에 묶인 정보이고, 반응은 코스 전체에 대한 사용자 평가다.

---

## 3. MVP 기능 범위

### 3.1 탐색과 코스 선택

| ID | 기능 | 기준 |
|---|---|---|
| F1 | 지도 탐색 화면 | 서울의 초기 카메라 위치를 표시하고 이동·확대·축소를 지원한다. |
| F2 | 코스 하프시트 | 축소·확장 상태를 제공하며 완전히 닫히지 않는다. |
| F3 | 초기 코스 목록 | 서버가 제공하는 시드 코스 2개를 표시한다. |
| F4 | 코스 선택 | 카드 선택 시 지도에 경로, 시작·종료 지점, 요소를 표시한다. |
| F5 | 요소 상세 | 요소 선택 시 카테고리, 경로상 거리, 제목, 설명을 표시한다. |
| F6 | 선택 해제 | 같은 코스를 다시 선택하거나 닫기 명령으로 기본 상태로 돌아간다. |

목록과 하프시트는 CoCo의 핵심 탐색 구조이므로 제거하지 않는다.

### 3.2 사용자와 보관함

| ID | 기능 | 기준 |
|---|---|---|
| F7 | 게스트 계정 | 첫 실행 시 서버에서 계정과 토큰을 발급받는다. 로그인 화면은 없다. |
| F8 | 안전한 토큰 저장 | 게스트 토큰은 iOS Keychain에 저장한다. |
| F9 | 스크랩 | 코스를 저장하거나 해제하고, 보관함에서 스크랩 코스를 본다. |
| F10 | 내 코스 | 현재 사용자가 만든 코스를 보관함에서 본다. |

앱 삭제나 기기 변경 시 게스트 계정 복구는 보장하지 않는다. 계정 복구는 Sign in with Apple을 도입하는 후속 단계에서 제공한다.

### 3.3 코스 반응

사용자는 한 코스에 아래 반응을 각각 선택하거나 해제할 수 있다. 여러 종류를 동시에 선택할 수 있지만 같은 종류는 한 번만 선택할 수 있다.

| API 값 | 표시 의미 |
|---|---|
| `LIKE` | 좋아요 |
| `HARD` | 힘들어요 |
| `SCENIC` | 경관이 좋아요 |

코스 화면에는 종류별 합계와 현재 사용자의 선택 상태를 함께 표시한다.

### 3.4 코스 등록

MVP의 코스는 현재 위치를 기록해서 만드는 방식이 아니라, 지도에서 계획해서 만든다.

1. 지도에서 출발지를 선택한다.
2. 필요한 경우 경유지를 최대 5개까지 순서대로 추가한다.
3. 도착지를 선택한다. 출발지와 같은 지점을 선택해 순환 코스를 만들 수 있다.
4. `MKDirections.Request.transportType = .walking`으로 구간별 보행 경로를 계산한다.
5. 전체 경로, 거리와 예상 시간을 미리 확인한다.
6. 코스 이름, 한 줄 설명과 난이도를 입력한다.
7. 경로 위에 코스 요소를 1개 이상 추가한다.
8. 최종 확인 후 서버에 등록한다.

현재 위치 권한을 요청하지 않는다. 위치 선택은 지도 이동과 탭으로만 수행하고, 검색과 지오코딩도 MVP에서 제외한다.

### 3.5 코스 요소

| API 값 | 의미 | 예시 |
|---|---|---|
| `VIEW` | 경관 또는 볼거리 | 전망 지점, 사진 명소 |
| `CAUTION` | 안전이나 주행 주의 | 인도 단절, 어두운 구간, 급경사 |
| `FACILITY` | 달리기에 도움이 되는 시설 | 화장실, 음수대, 휴식 공간 |

요소 필드:

- 카테고리
- 경로 위 좌표
- 출발점부터의 거리
- 제목
- 짧은 설명

MVP에서는 코스 작성자만 해당 코스의 요소를 등록·수정·삭제할 수 있다. 이미지 필드와 업로드 UI는 포함하지 않는다.

### 3.6 V2 확정 범위

V2는 MVP 기능을 TestFlight 테스터에게 배포하고 공개 인터넷 API를 안전하게 운영할 수 있는 상태를 목표로 한다.

| ID | 기능 | 기준 |
|---|---|---|
| V2-F1 | TestFlight 베타 배포 | 내부 테스트 후 외부 테스터 초대와 빌드 갱신 절차를 제공한다. |
| V2-F2 | Sign in with Apple | iOS `AuthenticationServices`를 사용하고 서버가 Apple identity token을 검증한다. |
| V2-F3 | 게스트 계정 승계 | 로그인 시 기존 게스트의 스크랩, 반응과 작성 코스를 Apple 계정에 유지한다. |
| V2-F4 | 로그아웃과 계정 삭제 | 토큰을 폐기하고 앱 안에서 계정 및 관련 개인정보 삭제를 시작할 수 있다. |
| V2-F5 | Cloudflare 공개 API | 일반 사용자는 Tailscale 없이 Cloudflare Tunnel의 HTTPS 호스트로 접근한다. |
| V2-F6 | 사설 운영 경로 | Tailscale은 개발자 SSH와 CI/CD의 Mac mini 접근에만 사용한다. |
| V2-F7 | 서버 자원 보호 | Edge와 애플리케이션 요청 제한, Tomcat 스레드·연결 상한, HikariCP 상한, 요청 크기 제한을 둔다. |
| V2-F8 | CI/CD | PR 검증, GHCR 이미지 발행, 승인된 Mac mini 배포와 헬스 체크를 자동화한다. |

V2의 첫 소셜 로그인 제공자는 Sign in with Apple이다. Google 또는 Kakao 로그인은 제공자 선택, 개인정보 처리와 계정 연결 정책을 별도로 확정한 뒤 추가한다. TestFlight는 Apple Developer 앱이 아니라 테스터의 TestFlight 앱을 통해 설치한다.

---

## 4. 화면과 상태

### 4.1 최상위 구조

- 탐색: 지도, 코스 하프시트, 코스 선택, 반응과 스크랩
- 보관함: 스크랩한 코스와 내가 만든 코스
- 코스 등록: 지도 기반 경로 계획과 요소 입력 흐름

최상위 배치는 사용자 결정에 따라 iOS 탭 바로 확정했다. 현재 탭은 탐색과 보관함이며, 코스 등록 진입은 Phase 6에서 배치를 결정한다. 스크랩과 반응 버튼은 선택된 코스 요약 카드에 배치한다. 새로운 화면을 임의로 완성하지 않고, 첫 구현 전에 와이어 수준의 상태와 이동을 사용자에게 확인받는다.

### 4.2 탐색 화면 상태

| 상태 | 조건 | 표현 |
|---|---|---|
| 기본 | 선택 코스 없음, 시트 축소 | 지도와 코스 수 요약 |
| 목록 | 선택 코스 없음, 시트 확장 | 시드 및 사용자 코스 목록 |
| 선택 | 선택 코스 있음 | 경로·시작·종료·요소와 선택 코스 요약 |
| 요소 상세 | 선택 요소 있음 | 기존 선택 상태 위에 요소 상세 표시 |
| 로딩 | API 요청 중 | 기존 레이아웃을 유지하는 진행 상태 |
| 오류 | 요청 실패 | 원인에 맞는 짧은 메시지와 재시도 명령 |
| 빈 상태 | 보관함 또는 내 코스가 비어 있음 | 빈 상태 문구와 가능한 다음 명령 |

### 4.3 하프시트 제약

- 축소와 확장 두 단계가 있다.
- 시트를 아래로 밀어 완전히 닫을 수 없다.
- 축소 상태에서는 뒤쪽 지도와 요소를 조작할 수 있어야 한다.
- 모달 `.sheet`는 탭 바를 가려 최상위 탭 이동을 막으므로, 탭 바 구조 확정 이후에는 탐색 탭 내부의 두 단계 바텀 패널로 구현한다. 축소·확장 전환은 버튼과 드래그 제스처를 함께 제공한다.
- 요소 상세 표현은 하프시트와 충돌하지 않아야 하며, Figma와 HIG 검토 후 오버레이 또는 별도 시트 중 하나를 선택한다.

---

## 5. 데이터 모델

### 5.1 iOS 모델

```text
User
  id, displayName, accountType

Course
  id, ownerId, ownerName, name, summary, difficulty,
  locationLabel, distanceMeters, estimatedDurationSeconds,
  routeSource, routePoints, elements,
  scrapCount, reactionCounts, isScrapped, myReactions

RoutePoint
  id, sequence, latitude, longitude

CourseElement
  id, courseId, category, latitude, longitude,
  distanceFromStartMeters, title, description

CourseReaction
  courseId, userId, type
```

열거형:

- `Difficulty`: `EASY`, `MODERATE`, `HARD`
- `ElementCategory`: `VIEW`, `CAUTION`, `FACILITY`
- `ReactionType`: `LIKE`, `HARD`, `SCENIC`
- `RouteSource`: `PLANNED_MAPKIT`; 후속으로 `RECORDED_GPS`, `IMPORTED_GPX`, `PLANNED_KAKAO`

모델은 `Codable`, `Identifiable`, 값 타입을 기본으로 한다. 공용 모델에는 `CLLocationCoordinate2D`를 저장하지 않고, MapKit 경계에서 자체 좌표 타입과 변환한다.

### 5.2 데이터베이스

| 테이블 | 책임 |
|---|---|
| `users` | 게스트 및 향후 Apple 계정 |
| `external_identities` | V2 외부 로그인 제공자와 제공자별 사용자 식별자의 유일한 연결 |
| `auth_tokens` | 해시된 게스트 인증 토큰과 만료 상태 |
| `courses` | 코스 기본 정보와 작성자 |
| `course_route_points` | 순서가 있는 경로 좌표 |
| `course_elements` | 경로 위 요소와 카테고리 |
| `course_scraps` | 사용자와 코스의 유일한 스크랩 관계 |
| `course_reactions` | 사용자·코스·반응 종류의 유일한 관계 |

`course_scraps`는 `(user_id, course_id)`, `course_reactions`는 `(user_id, course_id, reaction_type)`에 유일 제약을 둔다. 코스와 요소 삭제 시 연관 데이터 처리 방식은 마이그레이션에 명시한다.

---

## 6. 기술과 아키텍처

### 6.1 iOS

- SwiftUI
- MapKit 네이티브 `Map`
- Observation의 `@Observable`
- Swift Concurrency와 `URLSession`
- Keychain 기반 토큰 저장
- iOS 26.2 배포 타깃
- `HIGAgentSkills-main`의 OS 27 HIG 자료를 디자인 참고 기준으로 사용

지도 렌더링은 `MapCanvasView`에 집중시키고 네트워크와 상태 저장은 뷰에서 분리한다. 앱의 도메인 좌표 모델은 지도 SDK에 종속시키지 않는다.

### 6.2 서버

- Java 21 LTS
- Spring Boot 4.1.x
- Gradle
- Spring Web, Validation, Data JPA, Security, Actuator
- PostgreSQL
- Flyway 데이터베이스 마이그레이션

서버는 사용자 식별, 코스·요소·스크랩·반응 저장과 권한 검증을 담당한다. MapKit 경로 계산은 iOS에서 수행하고 서버는 확정된 코스 데이터를 검증해 저장한다.

### 6.3 Mac mini 배포

- 운영체제는 Fedora Asahi Remix Server이며 Docker Engine과 systemd를 사용한다.
- Spring 애플리케이션과 PostgreSQL을 Docker Compose로 실행한다.
- GitHub Actions의 ARM64 호스티드 러너가 테스트 후 JAR를 포함한 API 이미지를 GHCR에 발행한다.
- Mac mini는 서버 소스를 clone하거나 Gradle 빌드를 수행하지 않고 배포 번들과 GHCR 이미지만 사용한다.
- PostgreSQL 포트는 외부에 공개하지 않는다.
- MVP 실기기 검증은 Tailscale Serve를 사용할 수 있다.
- V2 일반 앱 요청은 Cloudflare Tunnel을 통해 `cloudflared`에서 Spring으로 전달한다.
- Mac mini의 공인 IP와 Spring 포트는 인터넷에 직접 공개하지 않는다.
- Tailscale은 개발자 SSH와 GitHub Actions 배포 경로에만 사용한다.
- iOS 앱은 HTTPS API만 사용한다.
- 서버 설정과 비밀값은 환경 변수로 주입한다.
- 헬스 체크, 컨테이너 재시작 정책과 데이터 볼륨 백업 절차를 둔다.
- Wi-Fi에서는 SSH와 Cockpit을 허용하지 않고 Tailscale 전용 firewalld 관리 존에서만 허용한다.
- SSH는 `joonha` 공개키 로그인만 허용하고 root와 비밀번호 로그인을 차단한다.

Nginx는 V2 초기 구성에 넣지 않는다. Cloudflare가 TLS와 Edge 보호를, `cloudflared`가 터널 프록시를, Spring 내장 Tomcat이 HTTP 처리를 담당한다. 여러 API 인스턴스의 로드밸런싱, 로컬 요청 버퍼링 또는 Blue/Green 라우팅이 필요해질 때 측정 근거와 함께 추가한다.

### 6.4 V2 서버 보호 기준

- Cloudflare WAF와 엔드포인트별 Rate Limit을 사용한다.
- Spring은 사용자·토큰 기준의 쓰기 요청 제한과 입력 검증을 수행한다.
- JSON 요청 본문 기본 상한은 256 KiB이며 초과 시 `413 Payload Too Large`를 반환한다.
- Tomcat 기본 상한은 작업 스레드 50개, 동시 연결 200개, 대기 연결과 작업 큐 각 50개다.
- HikariCP 기본 상한은 DB 연결 10개이며 연결 획득은 3초 안에 실패하도록 한다.
- API, PostgreSQL과 `cloudflared` 컨테이너에 메모리·CPU·PID 상한과 로그 회전을 둔다.
- `/actuator`는 공개 Cloudflare 호스트에서 노출하지 않고 로컬 또는 Tailscale 운영 경로에서만 확인한다.
- 목록 API는 페이지네이션과 최대 조회 개수를 강제한다.

### 6.5 Kakao API 제약

일반 Kakao Mobility 길찾기 API는 자동차 경로를 제공한다. 도보 길찾기 API는 제휴 파트너 전용이므로 일반 REST API 키만으로 사용할 수 없다.

- MVP 보행 경로 계산: MapKit `MKDirections`의 `.walking`
- 사용 금지: 러닝 경로 생성을 위한 Kakao 자동차 길찾기
- 후속 가능성: Kakao 도보 API 제휴 승인 후 서버의 경로 공급자 교체
- Kakao 키 용도: 추후 Kakao 지도 SDK 또는 허용된 Kakao API를 채택할 때만 사용

참고:

- [Apple MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections)
- [Kakao Mobility 길찾기 API](https://developers.kakaomobility.com/product/naviapi.html)
- [Kakao Mobility 도보 길찾기 API](https://developers.kakaomobility.com/affiliate/walking/directions.html)

---

## 7. API 초안

모든 보호 API는 `Authorization: Bearer <guest-token>`을 사용한다.

| Method | Path | 목적 |
|---|---|---|
| `POST` | `/api/v1/auth/guest` | 게스트 사용자와 토큰 발급 |
| `POST` | `/api/v1/auth/apple` | V2 Apple identity token 검증과 게스트 계정 승계 |
| `POST` | `/api/v1/auth/logout` | V2 현재 앱 토큰 폐기 |
| `DELETE` | `/api/v1/me` | V2 계정 및 관련 개인정보 삭제 요청 |
| `GET` | `/api/v1/courses` | 코스 목록 조회 |
| `GET` | `/api/v1/courses/{courseId}` | 코스 경로·요소·반응 상세 조회 |
| `POST` | `/api/v1/courses` | 현재 사용자의 코스 등록 |
| `GET` | `/api/v1/me/courses` | 내가 만든 코스 조회 |
| `GET` | `/api/v1/me/scraps` | 스크랩 코스 조회 |
| `PUT` | `/api/v1/courses/{courseId}/scrap` | 스크랩 저장 |
| `DELETE` | `/api/v1/courses/{courseId}/scrap` | 스크랩 해제 |
| `PUT` | `/api/v1/courses/{courseId}/reactions/{type}` | 반응 선택 |
| `DELETE` | `/api/v1/courses/{courseId}/reactions/{type}` | 반응 해제 |
| `POST` | `/api/v1/courses/{courseId}/elements` | 작성자의 요소 등록 |
| `PATCH` | `/api/v1/courses/{courseId}/elements/{elementId}` | 작성자의 요소 수정 |
| `DELETE` | `/api/v1/courses/{courseId}/elements/{elementId}` | 작성자의 요소 삭제 |
| `GET` | `/actuator/health` | 서버 상태 확인 |

오류 응답은 상태 코드, 안정적인 오류 코드, 사용자에게 직접 노출하지 않을 기술 메시지를 구분한다. API 계약은 서버 구현 전에 요청·응답 예시로 확정한다.

### 7.1 Phase 2 API 계약

게스트 발급 응답:

```json
{
  "user": {
    "id": "uuid",
    "displayName": "게스트 러너 A1B2",
    "accountType": "GUEST"
  },
  "token": "base64url-token",
  "expiresAt": "2026-08-21T12:00:00Z"
}
```

코스 목록 응답은 이후 페이지 정보 추가를 위해 배열을 `items`로 감싼다. Phase 2에서는 경로와 요소까지 포함한 코스 전체 표현을 반환한다.

```json
{
  "items": [
    {
      "id": "uuid",
      "ownerId": "uuid",
      "ownerName": "노을러너",
      "name": "한강 노을 라인",
      "summary": "여의도 한강공원을 따라 노을과 강바람을 즐기는 코스",
      "difficulty": "MODERATE",
      "locationLabel": "서울 영등포구",
      "distanceMeters": 5200,
      "estimatedDurationSeconds": 2520,
      "routeSource": "PLANNED_MAPKIT",
      "routePoints": [],
      "elements": [],
      "scrapCount": 0,
      "reactionCounts": { "like": 0, "hard": 0, "scenic": 0 },
      "isScrapped": false,
      "myReactions": []
    }
  ]
}
```

대표 오류 응답:

```json
{
  "status": 401,
  "code": "AUTH_TOKEN_INVALID",
  "message": "인증이 필요합니다.",
  "timestamp": "2026-07-22T12:00:00Z"
}
```

- `token` 원문은 발급 응답에서 한 번만 전달하고 서버에는 SHA-256 해시만 저장한다.
- `GET /api/v1/courses`와 상세 조회는 게스트 Bearer 토큰이 필요하다.
- JSON 열거형과 필드 이름은 5장의 iOS 모델 계약을 그대로 사용한다.

---

## 8. 개발 계획

사용자가 요청한 순서대로 최소 기능을 먼저 만들고, 인프라를 연결한 후 기능을 확장한다.

### Phase 0. 기준 확정

- SPEC와 AGENTS 개정
- iPhone OS 버전, Xcode 서명과 iOS 26.2 설치 확인
- Figma와 HIG 기준으로 탐색 화면의 핵심 상태 확인

### Phase 1. iOS 핵심 경험

- 공용 모델과 로컬 시드 코스 2개 작성
- 지도, 폴리라인, 시작·종료 지점 구현
- 경로 위 요소 3종과 요소 상세 구현
- 코스 목록과 축소·확장 하프시트 구현
- 선택과 선택 해제 흐름 구현

이 단계가 끝나면 서버 없이도 CoCo의 핵심 가치를 확인할 수 있어야 한다.

### Phase 2. 서버와 데이터베이스

- Spring Boot 프로젝트와 PostgreSQL 구성
- Flyway 스키마와 시드 코스 2개 작성
- 코스 목록·상세 API와 자동화 테스트 구현
- Docker Compose로 로컬 실행 및 헬스 체크 확인

### Phase 3. Mac mini 인프라

- Mac mini에 Docker Compose 배포
- GitHub Actions 서버 테스트와 GHCR ARM64 이미지 발행
- Cloudflare Tunnel 공개 HTTPS 연결
- Tailscale 기반 사설 SSH와 CI/CD 관리 경로 구성
- PostgreSQL 외부 비공개, 환경 변수, 재시작과 백업 확인
- Tomcat, HikariCP, 요청 크기와 컨테이너 자원 상한 확인
- iPhone에서 실제 서버 헬스 체크와 코스 조회 확인

### Phase 4. iOS API 전환

- 로컬 목데이터를 서버 저장소로 교체
- 로딩·오류·재시도·빈 상태 구현
- 디코딩과 상태 저장 테스트 추가

### Phase 5. 사용자 기능

- 게스트 계정과 Keychain 토큰
- 스크랩과 보관함
- 코스 반응과 집계
- 내 코스 목록

### Phase 6. 코스와 요소 등록

- 지도 탭으로 출발·경유·도착 선택
- MapKit 보행 경로 계산과 미리보기
- 코스 정보 입력과 서버 등록
- 경로 위 요소 등록·수정·삭제 및 작성자 권한 검증

### Phase 7. 품질 강화

- HIG 검토와 Figma 시각 보정
- Dynamic Type, VoiceOver 레이블, 대비와 터치 영역 확인
- 다양한 iPhone 크기, 네트워크 실패와 재실행 검증
- 핵심 시나리오 회귀 테스트

### Phase 8. V2 계정과 베타 배포

- Sign in with Apple과 서버 토큰 검증
- 게스트 계정 승계, 로그아웃과 앱 내 계정 삭제
- Tailscale 기반 승인형 Mac mini CD와 헬스 체크·롤백 자동화
- TestFlight 내부 테스트 후 외부 테스트

---

## 9. 확인 시나리오

| ID | 조작 | 기대 결과 |
|---|---|---|
| S1 | 앱을 처음 실행 | 게스트 계정이 생성되고 현재 위치 권한 없이 탐색 화면이 열린다. |
| S2 | 하프시트를 확장 | 서버의 초기 코스 2개가 표시된다. |
| S3 | 코스 카드 선택 | 시트가 축소되고 지도에 경로·시작·종료·요소가 표시된다. |
| S4 | 서로 다른 요소 선택 | 각 카테고리와 일치하는 제목·설명·경로상 거리가 표시된다. |
| S5 | 코스를 스크랩하고 앱 재실행 | 같은 게스트 계정의 보관함에 코스가 유지된다. |
| S6 | `LIKE`, `HARD`, `SCENIC` 선택 및 해제 | 선택 상태와 서버 집계가 중복 없이 반영된다. |
| S7 | 코스 등록에서 출발·경유·도착 선택 | 보행 경로 미리보기와 거리·예상 시간이 표시된다. |
| S8 | 요소 없이 등록 시도 | 요소가 1개 이상 필요하다는 검증이 표시된다. |
| S9 | 요소를 추가하고 코스 등록 | 내 코스와 탐색 목록에 새 코스가 표시된다. |
| S10 | 다른 사용자 소유 요소 수정 요청 | 서버가 권한 오류로 거부한다. |
| S11 | Mac mini 서버 재시작 | 데이터가 유지되고 헬스 체크가 정상으로 복귀한다. |
| S12 | 네트워크를 끊고 새로고침 | 앱이 크래시하지 않고 오류와 재시도 동작을 제공한다. |
| V2-S1 | Tailscale이 없는 테스트 iPhone에서 실행 | Cloudflare HTTPS를 통해 API를 조회한다. |
| V2-S2 | 게스트가 Sign in with Apple 수행 | 기존 스크랩, 반응과 작성 코스가 유지된다. |
| V2-S3 | 256 KiB보다 큰 JSON 요청 | 서버가 본문을 처리하지 않고 `413`으로 거부한다. |
| V2-S4 | API 컨테이너에 과도한 연결 요청 | 설정한 스레드·연결·DB 풀 상한을 넘지 않고 빠르게 실패한다. |
| V2-S5 | TestFlight 초대 수락 | 테스터가 TestFlight에서 CoCo를 설치하고 업데이트한다. |

---

## 10. 완성 기준

### 제품

- [ ] 앱 이름과 화면 표시가 CoCo로 통일되어 있다.
- [ ] 코스 목록과 하프시트가 유지된다.
- [ ] 초기 코스 2개를 서버에서 조회할 수 있다.
- [ ] 경로, 요소, 요소 상세의 연결이 끊기지 않는다.
- [ ] 게스트 사용자별 스크랩, 반응과 내 코스가 구분된다.
- [ ] 계획한 코스와 요소를 등록할 수 있다.

### iOS

- [ ] iOS 26.2 실기기에서 Xcode 서명으로 설치하고 실행할 수 있다.
- [ ] 현재 위치 권한을 요청하지 않는다.
- [ ] 지원하지 않는 OS 27 전용 API를 사용하지 않는다.
- [ ] 핵심 UI가 HIG 로딩 절차에 따라 검토되었다.
- [ ] 로딩·오류·빈 상태에서 레이아웃이 깨지거나 크래시하지 않는다.

### 서버와 인프라

- [ ] Spring과 PostgreSQL 테스트가 통과한다.
- [ ] Mac mini에서 Docker Compose로 재시작 가능하다.
- [ ] PostgreSQL이 인터넷에 직접 노출되지 않는다.
- [ ] iPhone에서 HTTPS로 API를 호출할 수 있다.
- [ ] 저장소에 토큰, 비밀번호와 API 키가 포함되지 않는다.

### V2

- [ ] TestFlight 내부 및 외부 테스트 절차가 검증되었다.
- [ ] Sign in with Apple 로그인, 게스트 승계, 로그아웃과 계정 삭제가 동작한다.
- [ ] 일반 iPhone 사용자가 Tailscale 없이 Cloudflare HTTPS API에 접근한다.
- [ ] Cloudflare Tunnel 외에 Mac mini의 공개 인바운드 포트가 없다.
- [ ] 서버와 컨테이너 자원 상한이 설정되고 초과 요청 테스트가 통과한다.
- [ ] `main`의 승인된 이미지가 GHCR에서 Mac mini로 배포되고 롤백할 수 있다.

---

## 11. 스코프 제외와 후속 후보

아래 항목은 MVP v0.1에서 구현하지 않는다.

- 검색, 지오코딩과 코스 필터
- 현재 위치와 위치 권한
- 달리기 중 GPS 기록과 백그라운드 위치 수집
- GPX 가져오기와 내보내기
- 이미지 업로드, S3와 영상
- 댓글, 팔로우, 알림과 소셜 피드
- 공개 App Store 배포
- Kakao 지도 네이티브 SDK
- 제휴 전 Kakao 도보 길찾기 API
- 코스 추천 알고리즘과 관리자 운영 도구

후속 기능을 구현하려면 먼저 이 문서에서 MVP 또는 다음 버전의 확정 범위로 옮긴다.

---

## 12. 미결정 사항

- 코스 등록과 보관함의 최종 화면 구성은 Figma와 HIG 검토 후 확정한다.
- 공개 배포를 고려할 때 MapKit 경로 데이터의 저장·재사용 조건을 다시 확인한다.
- Kakao 도보 길찾기 제휴 가능 여부를 확인한 뒤 경로 공급자 변경을 결정한다.
- S3는 이미지가 다시 범위에 포함될 때 비용, 인증과 삭제 정책을 함께 결정한다.
- Google 또는 Kakao 로그인을 V2 이후에 추가할지와 계정 연결 우선순위를 결정한다.
- TestFlight 사용 전 Apple Developer Program 가입 상태와 App Store Connect 역할을 확인한다.
