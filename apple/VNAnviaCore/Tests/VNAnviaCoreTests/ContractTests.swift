import XCTest
@testable import VNAnviaCore
final class ContractTests:XCTestCase {
 func testURLRejectsNFDOriginalAndPunycodeSpellings()throws {
  XCTAssertTrue(Contract.isNFC("é"))
  XCTAssertFalse(Contract.isNFC("e\u{301}"))
  XCTAssertThrowsError(try LocalURL.analyze("https://cafe\u{301}.vn/path"))
  XCTAssertNil(Punycode.decode("xn--e-xbb"))
  XCTAssertNoThrow(try LocalURL.analyze("https://café.vn/path"))
 }
 func testURLResponseContainsExactEvidenceGuidanceAndMetadata()throws {
  let input="HTTP://name:secret@vietcombank.com.vn.attacker.example/path"
  let local=try LocalURL.analyze(input)
  let response=local.response
  XCTAssertEqual(response.processing_status,"COMPLETED")
  XCTAssertEqual(response.assessment,"MEDIUM")
  XCTAssertEqual(response.engine_version,"url-local-1.2")
  XCTAssertEqual(response.prompt_version,"none")
  XCTAssertEqual(response.rule_version,Contract.version)
  XCTAssertEqual(response.schema_version,"1.0")
  XCTAssertEqual(response.signals.count,3)
  XCTAssertEqual(response.signals[0].evidence_text,"@vietcombank.com.vn.attacker.example")
  XCTAssertFalse(response.signals.contains{$0.evidence_text.contains("secret")})
  XCTAssertTrue(response.signals.allSatisfy{Contract.evidence(input,$0.evidence_text)})
  XCTAssertFalse(response.recommendation_codes.isEmpty)
  XCTAssertLessThanOrEqual(response.recommendation_codes.count,3)
  let catalog=try Contract.object("rules"),guidance=catalog["guidance"] as! [String:String]
  XCTAssertTrue(response.recommendation_codes.allSatisfy{guidance[$0] != nil})
  XCTAssertFalse(response.limitations.isEmpty)
 }
 func testLowURLStillProvidesCaveatAndURLLimitation()throws {
  let local=try LocalURL.analyze("https://library.example/books")
  XCTAssertEqual(local.assessment,"LOW")
  XCTAssertTrue(local.response.signals.isEmpty)
  XCTAssertEqual(local.response.recommendation_codes,["LOW_CAVEAT","URL_LIMITATION"])
  // URL requests remain forbidden at the cloud request boundary.
  XCTAssertThrowsError(try Contract.validateRequest(AnalysisRequest(content:"https://library.example",inputType:"URL")))
 }
 func testNativeRequestBoundary()throws {
  let base=AnalysisRequest(content:"Nội dung tiếng Việt 😀")
  XCTAssertNoThrow(try Contract.validateRequest(base))
  let original=try JSONSerialization.jsonObject(with:JSONEncoder().encode(base)) as! [String:Any]
  let invalid:[(String,String)]=[
   ("request_id","00000000-0000-1000-8000-000000000000"),
   ("request_id","00000000-0000-4000-7000-000000000000"),
   ("request_id","AAAAAAAA-0000-4000-8000-000000000000"),
   ("request_id",base.request_id+"\n"),
   ("input_type","URL"),("privacy_ack_version","old"),("schema_version","2.0"),
   ("client_build",""),("client_build",String(repeating:"😀",count:65)),
   ("content"," text "),("content",String(repeating:"😀",count:4001))
  ]
  for (key,value) in invalid {
   var raw=original;raw[key]=value
   let request=try JSONDecoder().decode(AnalysisRequest.self,from:JSONSerialization.data(withJSONObject:raw))
   XCTAssertThrowsError(try Contract.validateRequest(request),key)
  }
  var boundary=original;boundary["client_build"]=String(repeating:"😀",count:64)
  let boundaryRequest=try JSONDecoder().decode(AnalysisRequest.self,from:JSONSerialization.data(withJSONObject:boundary))
  XCTAssertNoThrow(try Contract.validateRequest(boundaryRequest))
 }
 func testScalarEvidence()throws {
  XCTAssertEqual(try Contract.input(" A😀B ",type:"TEXT").unicodeScalars.count,3)
  XCTAssertFalse(Contract.evidence("a e\u{301} z","é"))
  XCTAssertTrue(Contract.evidence("a e\u{301} z","e\u{301}"))
  var g=GenerationGate();let old=g.next();_ = g.next();XCTAssertFalse(g.active(old))
 }
 func testSharedUnicodeAndEvidence()throws {
  let unicode=try JSONSerialization.jsonObject(with:Contract.data("unicode-fixtures")) as! [[String:Any]]
  for c in unicode {
   if c["valid"] as? Bool==true{let text=try Contract.input(c["content"] as! String,type:c["input_type"] as! String);XCTAssertEqual(Array(text.utf8),Array((c["trimmed"] as! String).utf8));XCTAssertEqual(text.unicodeScalars.count,c["codepoints"] as? Int)}
   else{XCTAssertThrowsError(try Contract.input(c["content"] as! String,type:c["input_type"] as! String))}
  }
  let evidence=try JSONSerialization.jsonObject(with:Contract.data("evidence-fixtures")) as! [[String:Any]]
  for c in evidence{XCTAssertEqual(Contract.evidence(c["content"] as! String,c["evidence_text"] as! String),c["valid"] as? Bool)}
  // Swift String cannot hold ill-formed UTF16. A strict decoder must reject that input before construction.
  let surrogate=Data([0x22,0x5c,0x75,0x64,0x38,0x30,0x30,0x22]);XCTAssertThrowsError(try JSONSerialization.jsonObject(with:surrogate,options:.fragmentsAllowed))
 }
 func testSharedURLFixtures()throws {
  // A separate URL fixture file avoids JSON's ill-formed UTF16 surrogate probe.
  let rows=try JSONSerialization.jsonObject(with:Contract.data("url-fixtures")) as! [[String:Any]]
  for c in rows {
   let context=c["context"] as? [String:[String]]
   do{let r=try LocalURL.analyze(c["content"] as! String,references:context?["reference_hosts"],shorteners:context?["shortener_hosts"])
    XCTAssertEqual(c["processing_status"] as? String,"COMPLETED",c["id"] as! String)
    XCTAssertEqual(r.assessment,c["assessment"] as? String,c["id"] as! String)
    XCTAssertEqual(r.signals,c["signals"] as? [String],c["id"] as! String)
   }catch{XCTAssertEqual(c["processing_status"] as? String,"FAILED",c["id"] as! String)}
  }
 }
}

