import XCTest
@testable import VNAnviaCore

final class WebsiteTests:XCTestCase {
 func testSharedWebsiteResponses()throws {
  let rows=try JSONSerialization.jsonObject(with:Contract.data("website-fixtures")) as! [[String:Any]]
  for row in rows {
   let request=try JSONDecoder().decode(WebsiteRequest.self,from:JSONSerialization.data(withJSONObject:row["request"]!))
   let response=try JSONSerialization.data(withJSONObject:row["response"]!)
   let valid=(try? WebsiteResult.decode(response,request:request)) != nil
   XCTAssertEqual(valid,row["valid"] as! Bool,row["id"] as! String)
  }
 }
}
