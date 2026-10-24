import Foundation
private final class NoRedirect:NSObject,URLSessionTaskDelegate {
 func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
}
public actor API {
 public static let endpoint=URL(string:"https://sv23.bcse-vju.com/vnanvia/")!
 private let session:URLSession
 private let websiteSession:URLSession
 private let redirect=NoRedirect()
 public init(){let c=URLSessionConfiguration.ephemeral;c.urlCache=nil;c.httpCookieStorage=nil;c.urlCredentialStorage=nil;c.timeoutIntervalForRequest=15;c.timeoutIntervalForResource=15;session=URLSession(configuration:c,delegate:NoRedirect(),delegateQueue:nil);let w=URLSessionConfiguration.ephemeral;w.urlCache=nil;w.httpCookieStorage=nil;w.urlCredentialStorage=nil;w.timeoutIntervalForRequest=35;w.timeoutIntervalForResource=35;websiteSession=URLSession(configuration:w,delegate:NoRedirect(),delegateQueue:nil)}
 private func call(_ path:String,token:String,body:Data?=nil,post:Bool=false)async throws->(data:Data,statusCode:Int) {
  var r=URLRequest(url:Self.endpoint.appendingPathComponent(path));r.httpMethod=(body != nil || post) ? "POST":"GET";r.httpBody=body
  if !token.isEmpty{r.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")};r.setValue("no-store",forHTTPHeaderField:"Cache-Control")
  if body != nil{r.setValue("application/json",forHTTPHeaderField:"Content-Type")}
  // Stream with a hard cap; never allocate an unbounded response body.
  let (bytes,response)=try await (path=="website/analyze" ? websiteSession:session).bytes(for:r)
  guard let http=response as? HTTPURLResponse else{throw VNError.unavailable}
  if http.statusCode==401{throw VNError.unauthorized}
  let analysisFailure=path=="analyze" && AnalysisHTTPResponse.failureCodes[http.statusCode] != nil
  guard http.statusCode==200 || analysisFailure || (path=="website/analyze" && [400,403,429,502,503,504].contains(http.statusCode)) else{throw VNError.unavailable}
  var data=Data()
  for try await byte in bytes {guard data.count<128*1024 else{throw VNError.invalidResponse};data.append(byte)}
  return (data,http.statusCode)
 }
 public func bootstrap()async throws->SessionBootstrap {
  let data=try await call("session",token:"",post:true).data
  guard let raw=try JSONSerialization.jsonObject(with:data) as? [String:Any],Set(raw.keys)==Set(["access_token","capabilities"])else{throw VNError.invalidResponse}
  let value=try JSONDecoder().decode(SessionBootstrap.self,from:data)
  guard (32...480).contains(value.access_token.utf8.count)else{throw VNError.invalidResponse}
  _ = try strictCapabilities(raw["capabilities"]);return value
 }
 private func strictCapabilities(_ value:Any?)throws->Capabilities {
  guard let raw=value as? [String:Any],Set(raw.keys)==Set(["api_version","schema_version","engine_version","rule_version","prompt_version","privacy_ack_version","contract_fingerprint","limits","server_time","token_expires_at","real_content_enabled","deployment_profile"]),
   let limits=raw["limits"] as? [String:Any],Set(limits.keys)==Set(["text_codepoints","url_codepoints","client_deadline_ms","backend_deadline_ms"])else{throw VNError.incompatible}
  let c=try JSONDecoder().decode(Capabilities.self,from:JSONSerialization.data(withJSONObject:raw));try c.validate();return c
 }
 public func capabilities(token:String)async throws->Capabilities {let data=try await call("capabilities",token:token).data;return try strictCapabilities(JSONSerialization.jsonObject(with:data))}
 public func analyze(_ request:AnalysisRequest,token:String)async throws->AnalysisResponse {
  try Contract.validateRequest(request)
  let response=try await call("analyze",token:token,body:JSONEncoder().encode(request))
  return try AnalysisHTTPResponse.decode(response.data,statusCode:response.statusCode,request:request)
 }
 public func website(_ request:WebsiteRequest,token:String)async throws->WebsiteResult {
  try request.validate()
  let response=try await call("website/analyze",token:token,body:JSONEncoder().encode(request))
  return try WebsiteResult.decode(response.data,request:request)
 }
}

// A server refusal is a validated FAILED response, never an assessment. Keep the
// HTTP status attached until contract validation so proxy errors cannot become
// results and a successful-looking body cannot hide a failed HTTP request.
enum AnalysisHTTPResponse {
 static let failureCodes:[Int:Set<String>]=[
  400:["INVALID_INPUT","UNSUPPORTED_URL"],413:["INVALID_INPUT"],
  403:["CONSENT_REQUIRED"],429:["RATE_LIMITED"],502:["AI_RESPONSE_INVALID"],
  503:["ANALYSIS_UNAVAILABLE"],504:["ANALYSIS_TIMEOUT"]
 ]
 static func decode(_ data:Data,statusCode:Int,request:AnalysisRequest)throws->AnalysisResponse {
  if statusCode==401{throw VNError.unauthorized}
  guard statusCode==200 || failureCodes[statusCode] != nil else{throw VNError.unavailable}
  guard data.count<=128*1024 else{throw VNError.invalidResponse}
  let response=try Contract.strictResponse(data,request:request)
  if statusCode==200 {
   guard response.processing_status=="COMPLETED" else{throw VNError.invalidResponse}
  }else{
   guard response.processing_status=="FAILED",let code=response.error_code,
    failureCodes[statusCode]?.contains(code)==true else{throw VNError.invalidResponse}
  }
  return response
 }
}

