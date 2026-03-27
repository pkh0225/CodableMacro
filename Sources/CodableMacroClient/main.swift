import Foundation
import CodableMacro

@Codable
struct TestB {
    var age: Int
    var bbb: Int
}

enum TestEnum: String, Codable {
    case aaa
    case bbb
}

// ✅ CodableData가 CodableAfterProtocol 채택 → afterParsedTypes에 명시
@Codable
nonisolated public struct UserMetaCodable: CodableAfterProtocol {
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

    var bbb: TestB?

    @Default(TestEnum.aaa)
    var enumtest: TestEnum

    var int64: Int64 

    nonisolated mutating public func afterParsed() {
        print("UserMetaCodable 000 afterParsed")
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
struct CodableData: CodableAfterProtocol {
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
struct CodableData2: CodableAfterProtocol {
    var title: String      // ValueCoder 자동 적용
    var count: Int         // ValueCoder 자동 적용
    var price: Double      // ValueCoder 자동 적용

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
    print("codableData2 (\(userMeta.codableData2.count)개) — price는 JSON 항목의 값:")
    for (i, item) in userMeta.codableData2.enumerated() {
        print("  [\(i)] title: \(item.title), count: \(item.count), price: \(item.price)")
    }
} catch {
    print("UserMetaCodable JSON 로드/파싱 실패:", error)
}
