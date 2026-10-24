import XCTest
@testable import VNAnviaCore

final class CharacterTests:XCTestCase {
 func testSharedCharacterFixtures()throws {
  let cases=try JSONSerialization.jsonObject(with:Contract.data("character-fixtures")) as! [[String:Any]]
  for c in cases {
   let r=try CharacterInspector.inspect(c["unicode_host"] as! String,asciiHost:c["ascii_host"] as! String,references:c["reference_hosts"] as! [String])
   XCTAssertEqual(r.suspicious,c["suspicious"] as! Bool,c["id"] as! String)
   XCTAssertEqual(r.referenceMatch,c["reference_match"] as? String,c["id"] as! String)
   XCTAssertEqual(r.characters.map{$0.codePoint},c["code_points"] as! [String],c["id"] as! String)
   XCTAssertTrue(CharacterInspector.notes(r).allSatisfy{$0.unicodeScalars.count<=300})
  }
 }
 func testPunycodeLookalikeURL()throws {
  let a=try LocalURL.analyze("https://vietcomb\u{430}nk.com.vn/").response
  let b=try LocalURL.analyze("https://xn--vietcombnk-6qi.com.vn/").response
  XCTAssertEqual(a.limitations,b.limitations)
  XCTAssertEqual(a.assessment,"INCONCLUSIVE")
  XCTAssertTrue(a.limitations.joined().contains("U+0430 Cyrillic"))
  XCTAssertEqual(a.engine_version,"url-local-1.2")
 }
}
