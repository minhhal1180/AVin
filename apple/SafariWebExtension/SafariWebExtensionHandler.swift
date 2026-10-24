import SafariServices
import VNAnviaCore
final class SafariWebExtensionHandler:NSObject,NSExtensionRequestHandling {
 func beginRequest(with context:NSExtensionContext){
  guard context.inputItems.count==1,let item=context.inputItems.first as? NSExtensionItem,
   let message=item.userInfo?[SFExtensionMessageKey] as? [String:Any],let op=message["operation"] as? String,
   Set(message.keys).isSubset(of:Set(["operation","token","remember","request","owner","request_id"])) else{return reply(context,["error_code":"INVALID_INPUT"])}
  Task{
   do{switch op{
    case "startSession":
     try keys(message,["operation","remember"])
     let c=try await NativeAccess.shared.bootstrap(remember:message["remember"] as? Bool==true)
     reply(context,["ok":true,"capabilities":try object(c),"remember":await NativeAccess.shared.remembers()])
    case "getCapabilities":
     try keys(message,["operation"])
     if let c=try await NativeAccess.shared.restore(){reply(context,["ok":true,"capabilities":try object(c),"remember":await NativeAccess.shared.remembers()])}else{reply(context,["error_code":"UNAUTHORIZED"])}
    case "storeAccess":
     try keys(message,["operation","token","remember"])
     guard let token=message["token"] as? String,(32...480).contains(token.utf8.count),token.unicodeScalars.allSatisfy({(33...126).contains($0.value)}) else{throw VNError.unauthorized}
     let c=try await NativeAccess.shared.connect(token,remember:message["remember"] as? Bool==true)
     reply(context,["ok":true,"capabilities":try object(c),"remember":await NativeAccess.shared.remembers()])
    case "setRemember":
     try keys(message,["operation","remember"])
     guard let remember=message["remember"] as? Bool else{throw VNError.invalidInput}
     try await NativeAccess.shared.setRemember(remember);reply(context,["ok":true,"remember":await NativeAccess.shared.remembers()])
    case "forgetAccess":try keys(message,["operation"]);await NativeAccess.shared.forget();reply(context,["ok":true])
    case "cancelAnalysis":
     try keys(message,["operation","owner","request_id"])
     let owner=try owner(message)
     let id=message["request_id"] as? String
     if message["request_id"] != nil{guard let id=id,id.range(of:"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",options:.regularExpression) != nil else{throw VNError.invalidInput}}
     await NativeAccess.shared.cancel(owner:owner,requestID:id);reply(context,["ok":true])
    case "websiteAnalyze":
     try keys(message,["operation","owner","request"])
     let owner=try owner(message)
     guard let raw=message["request"] as? [String:Any],Set(raw.keys)==Set(["request_id","url","consent_version","schema_version"])else{throw VNError.invalidInput}
     let r=try JSONDecoder().decode(WebsiteRequest.self,from:JSONSerialization.data(withJSONObject:raw));try r.validate()
     reply(context,try object(await NativeAccess.shared.website(r,owner:owner)))
    case "analyze":
     try keys(message,["operation","owner","request"])
     let owner=try owner(message)
     guard let raw=message["request"] as? [String:Any],Set(raw.keys)==Set(["request_id","input_type","content","privacy_ack_version","client_build","schema_version"])else{throw VNError.invalidInput}
     let r=try JSONDecoder().decode(AnalysisRequest.self,from:JSONSerialization.data(withJSONObject:raw))
     try Contract.validateRequest(r)
     reply(context,try object(await NativeAccess.shared.analyze(r,owner:owner)))
    default:throw VNError.invalidInput
   }}catch{reply(context,["error_code":error is CancellationError ? "CANCELLED":(error as? VNError)?.rawValue ?? "ANALYSIS_UNAVAILABLE"])}
  }
 }
 private func keys(_ message:[String:Any],_ allowed:Set<String>)throws{guard Set(message.keys).isSubset(of:allowed) else{throw VNError.invalidInput}}
 private func owner(_ message:[String:Any])throws->String{guard let value=message["owner"] as? String,!value.isEmpty,value.utf8.count<=256,!value.unicodeScalars.contains(where:{$0.value<32 || $0.value==127}) else{throw VNError.invalidInput};return value}
 private func object<T:Encodable>(_ value:T)throws->[String:Any]{try JSONSerialization.jsonObject(with:JSONEncoder().encode(value)) as! [String:Any]}
 private func reply(_ context:NSExtensionContext,_ value:[String:Any]){let item=NSExtensionItem();item.userInfo=[SFExtensionMessageKey:value];context.completeRequest(returningItems:[item])}
}

