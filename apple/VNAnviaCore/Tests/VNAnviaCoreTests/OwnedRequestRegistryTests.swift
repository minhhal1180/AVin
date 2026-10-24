import XCTest
@testable import VNAnviaCore

@MainActor final class OwnedRequestRegistryTests:XCTestCase {
 func testCancelOneOwnerLeavesAnotherRunning()async throws {
  let registry=OwnedRequestRegistry<Int>()
  let cancelled=try registry.start(owner:"panel-a",id:"a"){try await Task.sleep(nanoseconds:10_000_000_000);return 1}
  let other=try registry.start(owner:"panel-b",id:"b"){2}
  registry.cancel(owner:"panel-a",id:"a")
  do{_ = try await cancelled.value;XCTFail("Cancelled owner completed")}catch{XCTAssertTrue(error is CancellationError)}
  let actual=try await other.value;XCTAssertEqual(actual,2)
 }
 func testOldRequestCancelCannotCancelReplacement()async throws {
  let registry=OwnedRequestRegistry<Int>()
  let old=try registry.start(owner:"panel",id:"old"){try await Task.sleep(nanoseconds:10_000_000_000);return 1}
  let current=try registry.start(owner:"panel",id:"new"){3}
  registry.cancel(owner:"panel",id:"old")
  registry.finish(owner:"panel",id:"old")
  do{_ = try await old.value;XCTFail("Replaced request completed")}catch{XCTAssertTrue(error is CancellationError)}
  let actual=try await current.value;XCTAssertEqual(actual,3)
 }
 func testCancelBeforeStartRejectsOnlyMatchingOwnerAndID()async throws {
  let registry=OwnedRequestRegistry<Int>()
  registry.cancel(owner:"panel-a",id:"same-id")
  XCTAssertThrowsError(try registry.start(owner:"panel-a",id:"same-id"){1})
  let other=try registry.start(owner:"panel-b",id:"same-id"){2}
  let actual=try await other.value;XCTAssertEqual(actual,2)
 }
 func testDuplicateActiveAttemptIsRejected()async throws {
  let registry=OwnedRequestRegistry<Int>()
  let current=try registry.start(owner:"panel",id:"same"){4}
  XCTAssertThrowsError(try registry.start(owner:"panel",id:"same"){9})
  let actual=try await current.value;XCTAssertEqual(actual,4)
 }
 func testConnectionReplacementCancelsAllOwners()async throws {
  let registry=OwnedRequestRegistry<Int>()
  let a=try registry.start(owner:"a",id:"a"){try await Task.sleep(nanoseconds:10_000_000_000);return 1}
  let b=try registry.start(owner:"b",id:"b"){try await Task.sleep(nanoseconds:10_000_000_000);return 2}
  registry.cancelAll()
  for task in [a,b]{do{_ = try await task.value;XCTFail("Old connection request completed")}catch{XCTAssertTrue(error is CancellationError)}}
 }
}
