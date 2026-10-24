import XCTest
@testable import VNAnviaApp

final class AccessTests:XCTestCase {
 private final class MemoryStore:AccessStore,@unchecked Sendable {
  var value:Access?
  var failSave=false
  init(_ access:Access?){value=access}
  func load()->Access?{value}
  func save(_ access:Access)throws{if failSave{throw TestFailure.save};value=access}
  func forget(){value=nil}
 }
 private enum TestFailure:Error{case save}
 private func validAccess()->Access{
  let now=Date();return Access(token:"synthetic-native-test-only",createdAt:now.addingTimeInterval(-60),expiresAt:now.addingTimeInterval(600))
 }
 func testRestoredRememberStateAndImmediateOptOutPreserveRamDeadline()async throws {
  let original=validAccess(),store=MemoryStore(nil)
  store.value=original
  let native=NativeAccess(store:store)
  let restored=await native.remembers();XCTAssertTrue(restored)
  try await native.setRemember(false)
  XCTAssertNil(store.value)
  let remembered=await native.remembers();XCTAssertFalse(remembered)
  let expiry=await native.expiryDate();XCTAssertEqual(expiry,original.expiresAt)
  try await native.setRemember(true)
  XCTAssertEqual(store.value?.createdAt,original.createdAt)
  XCTAssertEqual(store.value?.expiresAt,original.expiresAt)
  XCTAssertEqual(store.value?.token,original.token)
 }
 func testSaveFailureLeavesCredentialOnlyInRam()async throws {
  let original=validAccess(),store=MemoryStore(nil)
  store.value=original
  let native=NativeAccess(store:store)
  try await native.setRemember(false);store.failSave=true
  do{try await native.setRemember(true);XCTFail("Expected store failure")}catch{}
  XCTAssertNil(store.value)
  let remembered=await native.remembers();XCTAssertFalse(remembered)
  let expiry=await native.expiryDate();XCTAssertEqual(expiry,original.expiresAt)
 }
 func testExpiredOrOverEightHourSavedAccessIsDiscarded()async {
  let now=Date()
  for old in [Access(token:"synthetic",createdAt:now.addingTimeInterval(-600),expiresAt:now.addingTimeInterval(-1)),
              Access(token:"synthetic",createdAt:now.addingTimeInterval(-1),expiresAt:now.addingTimeInterval(9*3600))]{
   let store=MemoryStore(old),native=NativeAccess(store:store)
   XCTAssertNil(store.value)
   let remembered=await native.remembers();XCTAssertFalse(remembered)
   let expiry=await native.expiryDate();XCTAssertNil(expiry)
  }
 }
 func testForgetDeletesCurrentSavedSession()async {
  let store=MemoryStore(validAccess()),native=NativeAccess(store:store)
  await native.forget()
  XCTAssertNil(store.value)
  let remembered=await native.remembers();XCTAssertFalse(remembered)
  let expiry=await native.expiryDate();XCTAssertNil(expiry)
 }
}
