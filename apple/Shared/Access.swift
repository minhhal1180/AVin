import Foundation
import Security
import VNAnviaCore

struct Access:Codable,Sendable {let token:String,createdAt:Date,expiresAt:Date
 var valid:Bool{Date()>=createdAt && Date()<expiresAt && expiresAt>createdAt && expiresAt.timeIntervalSince(createdAt)<=8*3600}
}
protocol AccessStore:Sendable {
 func load()->Access?
 func save(_ access:Access)throws
 func forget()
}
struct KeychainAccessStore:AccessStore {
 func load()->Access?{Credential.load()}
 func save(_ access:Access)throws{try Credential.save(access)}
 func forget(){Credential.forget()}
}

enum Credential {
 static var service:String{Bundle.main.bundleIdentifier!+".access"}
 static func forget(){SecItemDelete([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"demo"] as CFDictionary)}
 static func load()->Access? {
  let q:[CFString:Any]=[kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"demo",kSecReturnData:true,kSecMatchLimit:kSecMatchLimitOne,kSecAttrSynchronizable:false]
  var value:CFTypeRef?;guard SecItemCopyMatching(q as CFDictionary,&value)==errSecSuccess,let data=value as? Data,
   let access=try? JSONDecoder().decode(Access.self,from:data),access.valid else{forget();return nil}
  return access
 }
 static func save(_ access:Access)throws {
  guard access.valid else{throw VNError.unauthorized}
  forget();let q:[CFString:Any]=[kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"demo",kSecValueData:try JSONEncoder().encode(access),kSecAttrAccessible:kSecAttrAccessibleWhenUnlockedThisDeviceOnly,kSecAttrSynchronizable:false]
  guard SecItemAdd(q as CFDictionary,nil)==errSecSuccess else{throw VNError.unavailable}
 }
}
actor NativeAccess {
 static let shared=NativeAccess()
 private var access:Access?
 private var remembering:Bool
 private var generation=0
 private let api=API()
 private let store:any AccessStore
 private let requests=OwnedRequestRegistry<AnalysisResponse>()
 private let websiteRequests=OwnedRequestRegistry<WebsiteResult>()
 init(store:any AccessStore=KeychainAccessStore()){
  self.store=store
  let saved=store.load();access=saved?.valid==true ? saved:nil;remembering=access != nil
  if saved != nil && access==nil{store.forget()}
 }
 func forget(){generation+=1;requests.cancelAll();websiteRequests.cancelAll();access=nil;remembering=false;store.forget()}
 func remembers()->Bool{remembering && access?.valid==true}
 func expiryDate()->Date?{access?.valid==true ? access?.expiresAt:nil}
 func setRemember(_ remember:Bool)throws {
  if !remember{store.forget();remembering=false;return}
  guard let a=access,a.valid else{forget();throw VNError.unauthorized}
  do{try store.save(a);remembering=true}
  catch{store.forget();remembering=false;throw error}
 }
 func restore()async throws->Capabilities? {
  guard let a=access,a.valid else{forget();return nil};let g=generation
  let c=try await api.capabilities(token:a.token);try Task.checkCancellation()
  guard g==generation,access?.token==a.token,a.valid else{throw CancellationError()};return c
 }
 func bootstrap(remember:Bool=false)async throws->Capabilities {
  forget();let g=generation;let value=try await api.bootstrap();try Task.checkCancellation();guard g==generation else{throw CancellationError()}
  let now=Date();let a=Access(token:value.access_token,createdAt:now,expiresAt:value.capabilities.deadline(now:now))
  guard a.valid else{throw VNError.unauthorized}
  access=a;try setRemember(remember);return value.capabilities
 }
 func connect(_ token:String,remember:Bool)async throws->Capabilities {
  forget();let g=generation;let c=try await api.capabilities(token:token)
  try Task.checkCancellation();guard g==generation else{throw CancellationError()}
  let now=Date();let a=Access(token:token,createdAt:now,expiresAt:c.deadline(now:now))
  guard a.valid else{throw VNError.unauthorized}
  access=a;try setRemember(remember);return c
 }
 func cancel(owner:String,requestID:String?=nil){requests.cancel(owner:owner,id:requestID);websiteRequests.cancel(owner:owner,id:requestID)}
 func analyze(_ request:AnalysisRequest,owner:String="native-ui")async throws->AnalysisResponse {
  guard let a=access,a.valid else{forget();throw VNError.unauthorized}
  let g=generation;let client=api
  let task=try requests.start(owner:owner,id:request.request_id){try await client.analyze(request,token:a.token)}
  defer{requests.finish(owner:owner,id:request.request_id)}
  let response=try await withTaskCancellationHandler(operation:{try await task.value},onCancel:{task.cancel()})
  try Task.checkCancellation()
  guard g==generation,access?.token==a.token,a.valid,!task.isCancelled else{throw CancellationError()}
  return response
 }
 func website(_ request:WebsiteRequest,owner:String)async throws->WebsiteResult {
  guard let a=access,a.valid else{forget();throw VNError.unauthorized};try request.validate()
  let g=generation;let client=api
  let task=try websiteRequests.start(owner:owner,id:request.request_id){try await client.website(request,token:a.token)}
  defer{websiteRequests.finish(owner:owner,id:request.request_id)}
  let result=try await withTaskCancellationHandler(operation:{try await task.value},onCancel:{task.cancel()})
  try Task.checkCancellation();guard g==generation,access?.token==a.token,a.valid,!task.isCancelled else{throw CancellationError()};return result
 }
}
