import Foundation

public struct WebsiteRequest:Codable,Sendable {
 public let request_id:String,url:String,consent_version:String,schema_version:String
 public init(url:String){self.url=url;request_id=UUID().uuidString.lowercased();consent_version="website-2026-10-24.1";schema_version="website-1.1"}
 public func validate()throws {
  guard request_id.range(of:"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",options:.regularExpression) != nil,
   consent_version=="website-2026-10-24.1",schema_version=="website-1.1",url.unicodeScalars.count<=2048,
   url.unicodeScalars.allSatisfy({(33...126).contains($0.value)}),!url.contains("\\"),
   let u=URLComponents(string:url),u.scheme=="https",u.host != nil,u.user==nil,u.password==nil,u.port==nil || u.port==443 else{throw VNError.invalidInput}
 }
}
public struct WebsiteFinding:Codable,Sendable {public let kind:String,evidence_text:String,source:String,explanation:String,severity:String,source_id:String}
public struct WebsiteCheck:Codable,Sendable {public let name:String,status:String,note:String}
public struct WebsiteResult:Codable,Sendable {
 public let request_id:String,schema_version:String,processing_status:String,assessment:String?,error_code:String?,final_url:String?,screenshot_sha256:String?
 public let inspection_status:String
 public let checks:[WebsiteCheck]
 public let redirects:[String],findings:[WebsiteFinding],limitations:[String]
 public static func decode(_ data:Data,request:WebsiteRequest)throws->WebsiteResult {
  guard let raw=try JSONSerialization.jsonObject(with:data) as? [String:Any],
   Set(raw.keys)==Set(["request_id","schema_version","processing_status","assessment","error_code","final_url","redirects","findings","screenshot_sha256","limitations","inspection_status","checks"]),
   let items=raw["findings"] as? [[String:Any]],items.allSatisfy({Set($0.keys)==Set(["kind","evidence_text","source","explanation","severity","source_id"])})else{throw VNError.invalidResponse}
  guard let checks=raw["checks"] as? [[String:Any]],checks.allSatisfy({Set($0.keys)==Set(["name","status","note"])})else{throw VNError.invalidResponse}
  let r=try JSONDecoder().decode(WebsiteResult.self,from:data)
  guard r.request_id==request.request_id,r.schema_version=="website-1.1",r.redirects.count<=6,r.findings.count<=8,r.limitations.count<=8 else{throw VNError.invalidResponse}
  if r.processing_status=="FAILED"{guard r.assessment==nil,r.error_code != nil,r.findings.isEmpty,r.inspection_status=="ERROR",r.checks.isEmpty else{throw VNError.invalidResponse}}
  else{guard r.processing_status=="COMPLETED",["MEDIUM","INCONCLUSIVE"].contains(r.assessment ?? ""),r.error_code==nil,r.final_url != nil,!r.limitations.isEmpty,
   r.screenshot_sha256?.range(of:"^[0-9a-f]{64}$",options:.regularExpression) != nil,
   ["RISK_INDICATORS","NO_RISK_INDICATORS","INSUFFICIENT_DATA"].contains(r.inspection_status),
   (r.assessment=="MEDIUM")==r.findings.contains(where:{$0.severity=="WARNING"}),
   (r.inspection_status=="RISK_INDICATORS")==r.findings.contains(where:{$0.severity=="WARNING"}),
   r.checks.count==7,Set(r.checks.map{$0.name})==Set(["DOM_TEXT","HTML_SOURCE","FORMS","LINKS","JAVASCRIPT","NETWORK","SCREENSHOT"]),
   r.checks.allSatisfy({["CHECKED","PARTIAL","UNAVAILABLE"].contains($0.status) && $0.note.unicodeScalars.count<=512}),
   r.findings.allSatisfy({["DOM_TEXT","FORM_ACTION","LINK","HTML_SOURCE","SCRIPT"].contains($0.source) && !$0.evidence_text.isEmpty && ["INFO","WARNING"].contains($0.severity) && $0.evidence_text.unicodeScalars.count<=1000 && $0.explanation.unicodeScalars.count<=1000 && $0.kind.unicodeScalars.count<=64 && $0.source_id.unicodeScalars.count<=64}) else{throw VNError.invalidResponse}}
  return r
 }
}
