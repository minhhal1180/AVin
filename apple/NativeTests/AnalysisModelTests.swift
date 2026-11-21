import XCTest
import VNAnviaCore
@testable import VNAnviaApp

@MainActor final class AnalysisModelTests:XCTestCase {
 private func response(_ request:AnalysisRequest,error:String?=nil)throws->AnalysisResponse {
  var raw:[String:Any]=["request_id":request.request_id,"processing_status":error==nil ? "COMPLETED":"FAILED",
   "assessment":error==nil ? "LOW" as Any:NSNull(),"signals":[],"recommendation_codes":error==nil ? ["LOW_CAVEAT"]:[],
   "limitations":error==nil ? ["Synthetic test response; not a safety guarantee."]:[],
   "engine_version":Contract.engine,"rule_version":Contract.version,"schema_version":"1.0","prompt_version":Contract.prompt]
  if let error=error{raw["error_code"]=error}
  return try Contract.strictResponse(JSONSerialization.data(withJSONObject:raw),request:request)
 }
 func testBlockedContentOpensExplanationWithoutAssessmentAndKeepsDraft()async throws {
  let request=AnalysisRequest(content:"Synthetic test input")
  let failed=try response(request,error:"CONSENT_REQUIRED")
  let model=AnalysisModel(analyze:{_ in failed})
  model.draft=request.content;model.consent=request
  await model.submit(request)?.value
  XCTAssertTrue(model.showingOutcome);XCTAssertFalse(model.busy)
  XCTAssertEqual(model.failureCode,"CONSENT_REQUIRED");XCTAssertNil(model.result)
  XCTAssertEqual(model.draft,request.content)
  // The current server accepts general text. A policy refusal must explain the
  // refusal, rather than incorrectly reverting to the historical samples-only mode.
  XCTAssertTrue(model.message.contains("Máy chủ chưa cho phép"))
  XCTAssertFalse(model.message.contains("mẫu mô phỏng đã duyệt"))
  XCTAssertFalse(model.message.contains("kiểm tra kết nối"))
 }
 func testCompletedResponseOpensResultAndEditingInvalidatesIt()async throws {
  let request=AnalysisRequest(content:"Synthetic test input"),completed=try response(request)
  let model=AnalysisModel(analyze:{_ in completed})
  model.draft=request.content;model.consent=request
  await model.submit(request)?.value
  XCTAssertTrue(model.showingOutcome);XCTAssertEqual(model.result?.assessment,"LOW");XCTAssertNil(model.failureCode)
  model.draft="Changed input"
  XCTAssertFalse(model.showingOutcome);XCTAssertNil(model.result);XCTAssertNil(model.consent)
 }
 func testDelayedResponseCannotOpenResultAfterDraftChanged()async throws {
  let request=AnalysisRequest(content:"Synthetic test input"),completed=try response(request)
  var finish:CheckedContinuation<AnalysisResponse,Never>?
  let started=expectation(description:"Analysis started")
  let model=AnalysisModel(analyze:{_ in await withCheckedContinuation{finish=$0;started.fulfill()}})
  model.draft=request.content;model.consent=request
  let task=model.submit(request)
  await fulfillment(of:[started],timeout:2)
  model.draft="Changed while waiting"
  finish?.resume(returning:completed)
  await task?.value
  XCTAssertFalse(model.showingOutcome);XCTAssertFalse(model.busy);XCTAssertNil(model.result)
 }
 func testSubmittingWithoutCurrentConsentDoesNotCallTransport()async {
  var calls=0
  let model=AnalysisModel(analyze:{_ in calls+=1;throw VNError.unavailable})
  XCTAssertNil(model.submit(AnalysisRequest(content:"Synthetic test input")))
  XCTAssertEqual(calls,0);XCTAssertFalse(model.busy);XCTAssertFalse(model.showingOutcome)
 }
 func testDemoReplacesDraftButDoesNotSubmitOrGrantConsent() {
  var calls=0
  let model=AnalysisModel(analyze:{_ in calls+=1;throw VNError.unavailable})
  model.type="URL";model.draft="https://library.example"
  model.consent=AnalysisRequest(content:"Old snapshot")
  model.useDemo()
  XCTAssertEqual(model.type,"TEXT");XCTAssertEqual(model.draft,AnalysisFeedback.demoText)
  XCTAssertNil(model.consent);XCTAssertEqual(calls,0);XCTAssertFalse(model.showingOutcome)
 }
 func testImageTextIsEditableAndOnlySubmitsAfterCurrentConsent()async throws {
  var submitted:[AnalysisRequest]=[]
  let model=AnalysisModel(analyze:{request in
   submitted.append(request)
   return try self.response(request)
  })
  let capabilities:[String:Any]=[
   "api_version":"1","schema_version":"1.0","engine_version":Contract.engine,
   "rule_version":Contract.version,"prompt_version":Contract.prompt,"privacy_ack_version":Contract.privacy,
   "contract_fingerprint":try XCTUnwrap(Contract.object("metadata")["contract_fingerprint"] as? String),
   "limits":["text_codepoints":4000,"url_codepoints":2048,"client_deadline_ms":15000,"backend_deadline_ms":12000],
   "server_time":1000,"token_expires_at":4600,"real_content_enabled":true,"deployment_profile":"lab-vps"
  ]
  model.capabilities=try JSONDecoder().decode(Capabilities.self,from:JSONSerialization.data(withJSONObject:capabilities))
  model.type="URL"
  model.useImageText("Chữ đọc từ ảnh")
  XCTAssertEqual(model.type,"TEXT")
  XCTAssertEqual(model.draft,"Chữ đọc từ ảnh")
  XCTAssertEqual(model.primaryActionTitle,"Kiểm tra văn bản")
  XCTAssertNil(model.consent)
  model.start()
  let old=try XCTUnwrap(model.consent)
  model.draft="Chữ đã sửa"
  XCTAssertEqual(model.primaryActionTitle,"Kiểm tra văn bản")
  XCTAssertNil(model.submit(old))
  model.start()
  let request=try XCTUnwrap(model.consent)
  XCTAssertEqual(request.content,"Chữ đã sửa")
  XCTAssertTrue(submitted.isEmpty)
  await model.submit(request)?.value
  XCTAssertEqual(submitted.map(\.content),["Chữ đã sửa"])
 }
 func testCancelledPickerAndStaleOCRPreserveExistingDraft() {
  let model=AnalysisModel()
  model.draft="Bản nháp trước đó"
  model.beginImage()
  model.selectImage(nil)
  model.importSelectedImage()
  model.receive(.success("Chữ từ lượt cũ"),generation:0)
  XCTAssertEqual(model.draft,"Bản nháp trước đó")
  XCTAssertNil(model.imageSource)
  XCTAssertFalse(model.readingImage)
  XCTAssertFalse(model.busy)
 }
 func testLocalURLResultOpensWithoutCloudConnection() {
  var calls=0
  let model=AnalysisModel(analyze:{_ in calls+=1;throw VNError.unavailable})
  model.type="URL";model.draft="https://library.example/books";model.start()
  XCTAssertTrue(model.showingOutcome);XCTAssertNotNil(model.local)
  XCTAssertNil(model.capabilities);XCTAssertNil(model.consent);XCTAssertEqual(calls,0)
 }
 func testUnauthorizedPointsToReconnectWithoutCreatingAssessment()async {
  let model=AnalysisModel(analyze:{_ in throw VNError.unauthorized})
  let request=AnalysisRequest(content:"Synthetic test input");model.consent=request
  await model.submit(request)?.value
  XCTAssertTrue(model.showingOutcome);XCTAssertEqual(model.failureCode,"UNAUTHORIZED")
  XCTAssertNil(model.result);XCTAssertTrue(model.message.contains("Dịch vụ"))
 }
}
