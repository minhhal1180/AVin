import Foundation

// Confine this registry to its owning actor. It never handles credentials or content.
public final class OwnedRequestRegistry<Value: Sendable> {
 private struct Entry { let id:String; let task:Task<Value,Error> }
 private var active:[String:Entry]=[:]
 private var cancelled:[String]=[]
 public init(){}
 private func key(_ owner:String,_ id:String)->String{owner+"\u{0}"+id}
 private func rememberCancellation(_ owner:String,_ id:String){
  let value=key(owner,id)
  if !cancelled.contains(value){cancelled.append(value)}
  if cancelled.count>256{cancelled.removeFirst(cancelled.count-256)}
 }
 public func start(owner:String,id:String,operation:@escaping @Sendable ()async throws->Value)throws->Task<Value,Error>{
  guard !cancelled.contains(key(owner,id)) else{throw CancellationError()}
  guard active[owner]?.id != id else{throw VNError.invalidInput}
  if let old=active[owner]{rememberCancellation(owner,old.id);old.task.cancel()}
  let task=Task{try Task.checkCancellation();return try await operation()}
  active[owner]=Entry(id:id,task:task);return task
 }
 public func finish(owner:String,id:String){if active[owner]?.id==id{active.removeValue(forKey:owner)}}
 public func cancel(owner:String,id:String?=nil){
  if let id=id{rememberCancellation(owner,id)}
  guard let entry=active[owner],id==nil || entry.id==id else{return}
  rememberCancellation(owner,entry.id);entry.task.cancel();active.removeValue(forKey:owner)
 }
 public func cancelAll(){
  for (owner,entry) in active{rememberCancellation(owner,entry.id);entry.task.cancel()}
  active.removeAll()
 }
}
