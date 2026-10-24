import XCTest
@testable import VNAnviaCore

final class TransportTests:XCTestCase {
 private func body(_ request:AnalysisRequest,code:String?=nil)->[String:Any] {
  var value:[String:Any]=[
   "request_id":request.request_id,"schema_version":"1.0",
   "engine_version":Contract.engine,"rule_version":Contract.version,"prompt_version":Contract.prompt,
   "processing_status":code == nil ? "COMPLETED":"FAILED",
   "assessment":code == nil ? ("LOW" as Any):NSNull(),"signals":[],
   "recommendation_codes":code == nil ? ["LOW_CAVEAT"]:[],
   "limitations":code == nil ? ["No observed signal does not establish safety."]:[]
  ]
  if let code=code{value["error_code"]=code}
  return value
 }
 private func decode(_ value:[String:Any],status:Int,request:AnalysisRequest)throws->AnalysisResponse {
  try AnalysisHTTPResponse.decode(JSONSerialization.data(withJSONObject:value),statusCode:status,request:request)
 }
 private func assertError(_ expected:VNError,_ action:()throws->Void,file:StaticString=#filePath,line:UInt=#line) {
  XCTAssertThrowsError(try action(),file:file,line:line){error in
   XCTAssertEqual(error as? VNError,expected,file:file,line:line)
  }
 }

 func testKnownHTTPFailuresRemainFailedWithoutAssessment()throws {
  let request=AnalysisRequest(content:"Synthetic transport test.")
  let cases:[(Int,String)]=[
   (400,"INVALID_INPUT"),(400,"UNSUPPORTED_URL"),(413,"INVALID_INPUT"),
   (403,"CONSENT_REQUIRED"),(429,"RATE_LIMITED"),(502,"AI_RESPONSE_INVALID"),
   (503,"ANALYSIS_UNAVAILABLE"),(504,"ANALYSIS_TIMEOUT")
  ]
  for (status,code) in cases {
   let result=try decode(body(request,code:code),status:status,request:request)
   XCTAssertEqual(result.processing_status,"FAILED")
   XCTAssertEqual(result.error_code,code)
   XCTAssertEqual(result.request_id,request.request_id)
   XCTAssertNil(result.assessment)
   XCTAssertTrue(result.signals.isEmpty)
  }
 }
 func testSuccessfulHTTPResponseStillUsesContractValidation()throws {
  let request=AnalysisRequest(content:"Synthetic transport test.")
  XCTAssertEqual(try decode(body(request),status:200,request:request).assessment,"LOW")
  var invalid=body(request);invalid["assessment"]="HIGH"
  assertError(.invalidResponse){_ = try self.decode(invalid,status:200,request:request)}
 }
 func testHTTPStatusCannotContradictPayload() {
  let request=AnalysisRequest(content:"Synthetic transport test.")
  for (status,code) in [(403,"RATE_LIMITED"),(429,"CONSENT_REQUIRED"),(503,"NETWORK_UNAVAILABLE")] {
   assertError(.invalidResponse){_ = try self.decode(self.body(request,code:code),status:status,request:request)}
  }
  assertError(.invalidResponse){_ = try self.decode(self.body(request),status:403,request:request)}
  assertError(.invalidResponse){_ = try self.decode(self.body(request,code:"CONSENT_REQUIRED"),status:200,request:request)}
 }
 func testFailureMustMatchRequestAndCurrentVersions() {
  let request=AnalysisRequest(content:"Synthetic transport test.")
  for (key,value) in [
   ("request_id",UUID().uuidString.lowercased()),("schema_version","2.0"),
   ("rule_version","0.2.0"),("engine_version","groq-old"),("prompt_version","old")
  ] {
   var invalid=body(request,code:"CONSENT_REQUIRED");invalid[key]=value
   assertError(.invalidResponse){_ = try self.decode(invalid,status:403,request:request)}
  }
 }
 func testFailureCannotContainAssessmentSignalsOrUnexpectedFields() {
  let request=AnalysisRequest(content:"Synthetic transport test.")
  var assessment=body(request,code:"CONSENT_REQUIRED");assessment["assessment"]="LOW"
  var recommendations=body(request,code:"CONSENT_REQUIRED");recommendations["recommendation_codes"]=["LOW_CAVEAT"]
  var unexpected=body(request,code:"CONSENT_REQUIRED");unexpected["debug"]="untrusted text"
  for invalid in [assessment,recommendations,unexpected] {
   assertError(.invalidResponse){_ = try self.decode(invalid,status:403,request:request)}
  }
 }
 func testUnrecognizedHTTPStatusAndUnauthorizedNeverBecomeResults() {
  let request=AnalysisRequest(content:"Synthetic transport test.")
  for status in [201,302,404,418,500] {
   assertError(.unavailable){_ = try self.decode(self.body(request,code:"CONSENT_REQUIRED"),status:status,request:request)}
  }
  assertError(.unauthorized){_ = try AnalysisHTTPResponse.decode(Data("not JSON".utf8),statusCode:401,request:request)}
 }
 func testMalformedAndOversizedHTTPFailureBodiesAreRejected() {
  let request=AnalysisRequest(content:"Synthetic transport test.")
  for data in [Data("<html>Gateway error</html>".utf8),Data("{}".utf8),Data("[]".utf8)] {
   XCTAssertThrowsError(try AnalysisHTTPResponse.decode(data,statusCode:403,request:request))
  }
  assertError(.invalidResponse){_ = try AnalysisHTTPResponse.decode(Data(repeating:32,count:128*1024+1),statusCode:403,request:request)}
 }
}
