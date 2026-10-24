import Foundation

public enum VNError: String, Error { case invalidInput="INVALID_INPUT", invalidResponse="AI_RESPONSE_INVALID", unauthorized="UNAUTHORIZED", unavailable="ANALYSIS_UNAVAILABLE", incompatible="INCOMPATIBLE_BACKEND", unsupportedURL="UNSUPPORTED_URL", timeout="ANALYSIS_TIMEOUT" }
public enum Contract {
 public static let version="0.3.0", privacy="2026-10-24.1", prompt="vi-context-1.3", engine="hybrid-gemini-groq-1.0"
 public static func data(_ name:String) throws -> Data { try Data(contentsOf: Bundle.module.url(forResource:name,withExtension:"json")!) }
 public static func object(_ name:String) throws -> [String:Any] { try JSONSerialization.jsonObject(with:data(name)) as! [String:Any] }
 public static func trim(_ value:String)->String {
  let ws=CharacterSet(charactersIn:"\t\n\u{b}\u{c}\r \u{85}\u{a0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}")
  return value.trimmingCharacters(in:ws)
 }
 public static func isNFC(_ value:String)->Bool{Array(value.utf8)==Array(value.precomposedStringWithCanonicalMapping.utf8)}
 public static func input(_ value:String,type:String) throws -> String {
  let s=trim(value)
  guard ["TEXT","URL"].contains(type), !s.isEmpty, s.unicodeScalars.count <= (type=="TEXT" ? 4000:2048),
        !s.unicodeScalars.contains(where:{$0.value < 9 || $0.value==11 || $0.value==12 || (14...31).contains($0.value) || $0.value==127}) else { throw VNError.invalidInput }
  return s
 }
 // String.contains uses canonical equivalence. Compare UTF8 bytes instead.
 public static func evidence(_ content:String,_ evidence:String)->Bool {
  let hay=Array(content.utf8), needle=Array(evidence.utf8)
  guard !trim(evidence).isEmpty, needle.count<=hay.count else{return false}
  return (0...(hay.count-needle.count)).contains{Array(hay[$0..<($0+needle.count)])==needle}
 }
 public static func validateRequest(_ request:AnalysisRequest)throws {
  guard request.input_type=="TEXT",request.schema_version=="1.0",request.privacy_ack_version==privacy,
   (1...64).contains(request.client_build.unicodeScalars.count),
   request.request_id.utf8.count==36,
   request.request_id.range(of:"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",options:.regularExpression) != nil,
   Array(try input(request.content,type:"TEXT").utf8)==Array(request.content.utf8) else{throw VNError.invalidInput}
 }
 public static func validate(_ r:AnalysisResponse,request:AnalysisRequest)throws {
  guard r.request_id==request.request_id, r.schema_version=="1.0",r.rule_version==version,
        r.engine_version==(request.input_type=="URL" ? "url-local-1.2":engine),r.prompt_version==(request.input_type=="URL" ? "none":prompt),
        Set(r.signals.map{$0.type}).count==r.signals.count,r.signals.count<=14,
        Set(r.recommendation_codes).count==r.recommendation_codes.count,r.recommendation_codes.count<=3 else{throw VNError.invalidResponse}
  let catalog=try object("rules"), rules=catalog["rules"] as! [[String:Any]],guidance=catalog["guidance"] as! [String:String]
  for signal in r.signals {
   guard evidence(request.content,signal.evidence_text),
         let rule=rules.first(where:{$0["signal_type"] as? String==signal.type && $0["input_type"] as? String==request.input_type}),
         rule["explanation"] as? String==signal.explanation else{throw VNError.invalidResponse}
  }
  guard r.recommendation_codes.allSatisfy({guidance[$0] != nil}) else{throw VNError.invalidResponse}
  guard r.limitations.count<=5,r.limitations.allSatisfy({!$0.isEmpty && $0.unicodeScalars.count<=300}) else{throw VNError.invalidResponse}
  if r.processing_status=="FAILED" {
   guard r.assessment==nil,r.signals.isEmpty,r.recommendation_codes.isEmpty,r.limitations.isEmpty,["INVALID_INPUT","UNSUPPORTED_URL","CONSENT_REQUIRED","NETWORK_UNAVAILABLE","ANALYSIS_TIMEOUT","AI_RESPONSE_INVALID","ANALYSIS_UNAVAILABLE","UNAUTHORIZED","RATE_LIMITED"].contains(r.error_code ?? "") else{throw VNError.invalidResponse}
  } else {
   guard r.processing_status=="COMPLETED",["LOW","MEDIUM","HIGH","INCONCLUSIVE"].contains(r.assessment ?? ""),r.error_code==nil,!r.limitations.isEmpty,!r.recommendation_codes.isEmpty,
     (r.assessment != "LOW" || r.signals.isEmpty),
     (!["HIGH","MEDIUM"].contains(r.assessment ?? "") || !r.signals.isEmpty),
     (request.input_type != "URL" || r.assessment != "HIGH") else{throw VNError.invalidResponse}
  }
 }
 public static func strictResponse(_ data:Data,request:AnalysisRequest)throws->AnalysisResponse {
  let raw=try JSONSerialization.jsonObject(with:data) as? [String:Any]
  var required:Set<String>=["request_id","processing_status","assessment","signals","recommendation_codes","limitations","engine_version","rule_version","schema_version","prompt_version"]
  if raw?["processing_status"] as? String=="FAILED"{required.insert("error_code")}
  guard let raw=raw,Set(raw.keys)==required else{throw VNError.invalidResponse}
  guard let signals=raw["signals"] as? [[String:Any]],signals.allSatisfy({Set($0.keys)==Set(["type","evidence_text","explanation"])}) else{throw VNError.invalidResponse}
  let r=try JSONDecoder().decode(AnalysisResponse.self,from:data);try validate(r,request:request);return r
 }
}
public struct AnalysisRequest: Codable, Sendable {
 public let request_id:String, input_type:String, content:String,privacy_ack_version:String,client_build:String,schema_version:String
 public init(content:String,inputType:String="TEXT"){self.request_id=UUID().uuidString.lowercased();self.input_type=inputType;self.content=content;self.privacy_ack_version=Contract.privacy;self.client_build="ios/0.3.0";self.schema_version="1.0"}
}
public struct Signal: Codable,Sendable { public let type:String,evidence_text:String,explanation:String }
public struct AnalysisResponse: Codable,Sendable {
 public let request_id:String,processing_status:String,assessment:String?,signals:[Signal],recommendation_codes:[String],limitations:[String],engine_version:String,rule_version:String,schema_version:String,prompt_version:String,error_code:String?
}
public struct Capabilities: Codable,Sendable {
 public let api_version:String,schema_version:String,engine_version:String,rule_version:String,prompt_version:String,privacy_ack_version:String,contract_fingerprint:String
 public let limits:[String:Int], server_time:Int,token_expires_at:Int,real_content_enabled:Bool,deployment_profile:String
 public func validate()throws {
  let expected=try Contract.object("metadata")
  guard api_version=="1",schema_version=="1.0",engine_version==Contract.engine,rule_version==Contract.version,
   prompt_version==Contract.prompt,privacy_ack_version==Contract.privacy,deployment_profile=="lab-vps",
   contract_fingerprint==expected["contract_fingerprint"] as? String,
   limits==["text_codepoints":4000,"url_codepoints":2048,"client_deadline_ms":15000,"backend_deadline_ms":12000],
   token_expires_at>server_time else{throw VNError.incompatible}
 }
 public func deadline(now:Date)->Date { min(Date(timeIntervalSince1970:TimeInterval(token_expires_at)),now.addingTimeInterval(TimeInterval(min(8*3600,token_expires_at-server_time)))) }
}
public struct GenerationGate {
 private var value=0
 public init(){}
 public mutating func next()->Int {value+=1;return value}
 public func active(_ generation:Int)->Bool {value==generation}
}


public struct SessionBootstrap:Codable,Sendable {public let access_token:String;public let capabilities:Capabilities}
