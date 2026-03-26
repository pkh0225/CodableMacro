import Foundation
import CodableMacro

// ✅ CodableData가 AfterParsedProtocol 채택 → afterParsedTypes에 명시
@Codable
struct UserMetaCodable: AfterParsedProtocol {
    var codableData: CodableData?       // → AfterParsedCoder 자동 적용
    var codableData2: [CodableData2]     // → AfterParsedCoder 자동 적용

    @Default("이름 없음")
    var name: String                    // → ValueCoder String 자동 변환
    @CodedAs("name3", "name4", "name5")
    var name2: String                   // → ValueCoder String 자동 변환, default ""

    @Default(20)
    var age: Int                        // → ValueCoder Int 자동 변환

    var score: Double                   // → ValueCoder Double 자동 변환, default 0

    var isAdmin: Bool                   // → ValueCoder Bool 자동 변환, default false

    @CodedAt("codableData", "bio")
    @Default("소개 없음")
    var biography: String

    mutating func afterParsed() {
        if name == "이름 없음" { name = "afterParsed() 적용 후 대체값 적용" }
    }
}

// ✅ afterParsedTypes 없는 경우
@Codable
struct SimpleModel {
    var title: String      // ValueCoder 자동 적용
    var count: Int         // ValueCoder 자동 적용
    var price: Double      // ValueCoder 자동 적용
    var names: [String]
    var dic: [String: String]

    @Ignore
    var any: CodableData?
}


@Codable
struct CodableData: AfterParsedProtocol {
    var bio: String      // ValueCoder 자동 적용
    var title: String      // ValueCoder 자동 적용
    var count: Int         // ValueCoder 자동 적용
    var price: Double      // ValueCoder 자동 적용
    var cgPrice: CGFloat      // ValueCoder 자동 적용

    mutating func afterParsed() {
        print("CodableData 111 afterParsed")
    }
}

@Codable
struct CodableData2: AfterParsedProtocol {
    var title: String      // ValueCoder 자동 적용
    var count: Int         // ValueCoder 자동 적용
    /// JSON의 `price` 대신 부모 `UserMetaCodable.score`를 디코딩 후 주입
    @CodedIn("UserMetaCodable", "score")
    var price: Double

    mutating func afterParsed() {
        print("CodableData 222 afterParsed")
    }
}

// MARK: - UserMetaCodable JSON 샘플 파싱 (`user_meta_sample.json`)

do {
    let jsonURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("user_meta_sample.json")
    let data = try Data(contentsOf: jsonURL)
    let decoder = JSONDecoder()
    let userMeta = try decoder.decode(UserMetaCodable.self, from: data)

    print("=== UserMetaCodable 파싱 결과 ===")
    dump(userMeta)
//    print("name: \(userMeta.name)")
//    print("name2: \(userMeta.name2)")
//    print("age: \(userMeta.age)")
//    print("score: \(userMeta.score)")
//    print("isAdmin: \(userMeta.isAdmin)")
//    print("biography (@CodedAt codableData.bio): \(userMeta.biography)")
//    if let cd = userMeta.codableData {
//        print("codableData — bio: \(cd.bio), title: \(cd.title), count: \(cd.count), price: \(cd.price)")
//    } else {
//        print("codableData: nil")
//    }
    print("codableData2 (\(userMeta.codableData2.count)개) — price는 부모 score(\(userMeta.score))로 주입:")
    for (i, item) in userMeta.codableData2.enumerated() {
        print("  [\(i)] title: \(item.title), count: \(item.count), price: \(item.price)")
    }
} catch {
    print("UserMetaCodable JSON 로드/파싱 실패:", error)
}
