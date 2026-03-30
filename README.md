# CodableMacro

`struct`에 `@Codable`을 붙이면 `CodingKeys`, `init(from:)`, `encode(to:)`를 컴파일 타임에 생성하는 Swift 매크로 패키지입니다. JSON API처럼 키 이름·중첩 경로·타입 불일치가 잦은 경우를 줄이기 위해 `@CodedAt`, `@CodedAs`, `@Default`, `@Ignore` 등의 프로퍼티 어트리뷰트와 **ValueCoder** 스타일의 관대한 디코딩을 지원합니다.

[MetaCodable](https://github.com/SwiftyLab/MetaCodable)의 아이디어를 참고해 구성했습니다.

## 요구 사항

- Swift 5.9 이상
- 매크로를 사용하는 타깃에서 Swift 매크로 활성화

**지원 플랫폼:** macOS 10.15+, iOS 15+, tvOS 13+, watchOS 6+

## 설치 (Swift Package Manager)

`Package.swift`의 `dependencies`에 추가합니다.

```swift
dependencies: [
    .package(url: "https://github.com/pkh0225/CodableMacro.git", from: "1.0.0"),
]
```

사용하는 타깃에서 `CodableMacro` 라이브러리를 링크합니다.

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "CodableMacro", package: "CodableMacro"),
    ]
)
```

소스 파일 상단에 다음을 추가합니다.

```swift
import CodableMacro
```

## 기본 사용법

`@Codable`은 **`struct`에만** 적용할 수 있습니다. 최소 한 개 이상의 디코딩 대상 저장 프로퍼티(`@Ignore`가 아닌 항목)가 있어야 합니다.

```swift
import CodableMacro

@Codable
struct User {
    var id: Int
    var name: String
}
```

생성되는 코드는 본체 `struct`의 **extension**으로 들어가며, `struct`에 붙인 접근 제어·기타 선언 수식어(`public`, `nonisolated` 등)는 `CodingKeys` / `init(from:)` / `encode(to:)`에도 동일하게 반영됩니다.

## 프로퍼티 어트리뷰트

| 어트리뷰트 | 역할 |
|-----------|------|
| `@CodedAt("a", "b", ...)` | JSON의 **중첩 경로**를 지정합니다. 마지막 세그먼트가 실제 키 이름이며, 경로가 2단 이상이면 중첩 `KeyedDecodingContainer`를 사용합니다. |
| `@CodedAs("key1", "key2", ...)` | **여러 키 이름 중 하나**로 올 수 있는 값을 디코딩합니다. 컨테이너에 존재하는 첫 번째 키를 사용하고, 없으면 기본값으로 대체합니다. |
| `@Default(값)` | 해당 키가 없거나 디코딩에 실패했을 때 사용할 **기본값**을 명시합니다. |
| `@Ignore` | `CodingKeys`·인코드·디코드에서 **제외**합니다. `init(from:)`에서는 기본값 식으로만 초기화합니다. |

`@Default`가 없어도 `var x: T = 초기값` 형태의 **선언부 초기값**이 있으면, 그 식이 동일한 용도의 기본값으로 사용됩니다.

### `@Ignore`와 비옵셔널

`@Ignore`인 프로퍼티가 옵셔널이 아니면, `init(from:)`에서 대입할 값이 필요합니다. 다음 중 하나가 있어야 합니다.

- `var foo: SomeType = ...` 선언부 초기값
- `@Default(...)`

그렇지 않으면 매크로가 컴파일 오류를 보고합니다.

## `CodableAfterProtocol`

`struct`가 `CodableAfterProtocol`을 채택하면, 합성된 `init(from:)`의 **맨 끝**에서 `afterParsed()`가 호출됩니다. 디코딩 직후 값 보정·파생 필드 설정 등에 쓸 수 있습니다.

```swift
@Codable
struct Model: CodableAfterProtocol {
    var title: String

    mutating func afterParsed() {
        // 디코딩 완료 후 처리
    }
}
```

## ValueCoder (관대한 디코딩)

프로퍼티 타입에 따라 JSON 원시 타입이 달라도 되도록, 생성 코드가 **여러 후보 타입**으로 순차 시도합니다. 예를 들어:

- **String**: `String`뿐 아니라 `Int`·`Double`도 문자열로 변환해 수용
- **정수/부동소수**: 문자열·다른 숫자 타입에서 변환 시도
- **Bool**: `Bool`, `Int`(0/비0), 여러 문자열 패턴(`"true"`, `"1"`, `"yes"` 등)
- **그 외 타입**: `decodeIfPresent` 후 실패 시 기본값

`@CodedAs`가 지정된 프로퍼티는 위 일반 ValueCoder 경로 대신, **다중 키 탐색** 전용 로직이 사용됩니다.

## 제한 사항 및 오류 메시지

- **클래스·enum 등 `struct`가 아닌 타입**에 `@Codable`을 쓰면: *"@Codable은 struct에만 사용할 수 있습니다"*
- 디코딩할 저장 프로퍼티가 모두 `@Ignore` 등으로 비어 있으면: *"@Codable: 디코딩할 저장 프로퍼티가 필요합니다"*

## 패키지 구성

| 타깃 | 설명 |
|------|------|
| `CodableMacro` | 공개 매크로 선언 및 `CodableAfterProtocol` |
| `CodableMacroImpl` | 컴파일러 플러그인(매크로 구현체) |
| `CodableMacroClient` | 예제 실행용 실행 파일 |

로컬에서 빌드·테스트:

```bash
swift build
swift test
```

예제 클라이언트 실행:

```bash
swift run CodableMacroClient
```

## 라이선스

`LICENSE` 파일을 따릅니다.
