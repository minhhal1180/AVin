import Foundation
public struct LocalURLResult {
 public let response:AnalysisResponse,host:String
 public var assessment:String{response.assessment!}
 public var signals:[String]{response.signals.map{$0.type}}
}
public enum LocalURL {
 public static func analyze(_ value:String,references:[String]?=nil,shorteners:[String]?=nil)throws->LocalURLResult {
  let text=try Contract.input(value,type:"URL")
  guard !text.unicodeScalars.contains(where:{CharacterSet.whitespacesAndNewlines.contains($0)||$0.value<=32||$0.value==92}),
   let schemeEnd=text.range(of:"://"),["http","https"].contains(String(text[..<schemeEnd.lowerBound]).lowercased()) else{throw VNError.unsupportedURL}
  let scheme=String(text[..<schemeEnd.lowerBound]).lowercased()
  let tail=String(text[schemeEnd.upperBound...]), authority=String(tail.prefix(while:{!"/?#".contains($0)}))
  guard !authority.isEmpty,authority.filter({$0=="@"}).count<=1 else{throw VNError.unsupportedURL}
  let hostPort=String(authority.split(separator:"@",omittingEmptySubsequences:false).last!)
  var rawHost=hostPort;var port:String?
  if hostPort.hasPrefix("[") {
   guard let end=hostPort.firstIndex(of:"]") else{throw VNError.unsupportedURL}
   rawHost=String(hostPort[...end])
   let rest=String(hostPort[hostPort.index(after:end)...])
   if !rest.isEmpty {guard rest.hasPrefix(":") else{throw VNError.unsupportedURL};port=String(rest.dropFirst())}
  } else {
   let parts=hostPort.split(separator:":",omittingEmptySubsequences:false)
   guard parts.count<=2 else{throw VNError.unsupportedURL}
   rawHost=String(parts[0]);if parts.count==2{port=String(parts[1])}
  }
  if let port=port {guard !port.isEmpty,port.allSatisfy({$0.isASCII&&$0.isNumber}),let n=Int(port),(1...65535).contains(n) else{throw VNError.unsupportedURL}}
  guard !rawHost.isEmpty,!rawHost.contains("%"),!rawHost.hasSuffix(".."),
   Contract.isNFC(rawHost),
   !rawHost.unicodeScalars.contains(where:{[0xdf,0x3c2,0x200c,0x200d,0x3002].contains(Int($0.value)) || (0xff00...0xffef).contains(Int($0.value))}) else{throw VNError.unsupportedURL}
  let dns=rawHost.hasSuffix(".") ? String(rawHost.dropLast()):rawHost
  let v6=dns.hasPrefix("[")
  let octets=dns.split(separator:".",omittingEmptySubsequences:false)
  let v4=octets.count==4 && octets.allSatisfy{part in !part.isEmpty && part.allSatisfy({$0.isASCII&&$0.isNumber}) && (part=="0" || !part.hasPrefix("0")) && (Int(part) ?? 999)<=255}
  if !v6 && !v4 {
   let last=String(octets.last ?? "").lowercased()
   guard !last.allSatisfy({$0.isASCII&&$0.isNumber}),!last.hasPrefix("0x") else{throw VNError.unsupportedURL}
  }
  guard let parsed=URL(string:text),let parsedHost=parsed.host else{throw VNError.unsupportedURL}
  let host=parsedHost.lowercased().trimmingCharacters(in:CharacterSet(charactersIn:"."))
  if !v6 && !v4 {
   guard host.utf8.count<=253,!host.contains("%"),host.split(separator:".",omittingEmptySubsequences:false).allSatisfy({label in
    !label.isEmpty && label.utf8.count<=63 && label.first != "-" && label.last != "-" && label.allSatisfy({$0.isASCII && ($0.isLetter || $0.isNumber || $0=="-")})
   }) else{throw VNError.unsupportedURL}
   for label in host.split(separator:".") where label.hasPrefix("xn--") {
    guard Punycode.decode(String(label)) != nil else{throw VNError.unsupportedURL}
   }
  }
  let snapshot=try Contract.object("url-references")
  let refs=references ?? snapshot["reference_hosts"] as! [String],shorts=shorteners ?? snapshot["shortener_hosts"] as! [String]
  var found:[(String,String)]=[]
  let evidenceHost=v6 ? String(rawHost.dropFirst().dropLast()):rawHost
  // Never echo userinfo credentials into evidence: the @ and destination suffice.
  if authority.contains("@"){found.append(("URL-001","@"+hostPort))}
  if refs.contains(where:{host != $0 && !host.hasSuffix("."+$0) && (host.hasPrefix($0+".")||host.contains("."+$0+"."))}){found.append(("URL-002",evidenceHost))}
  if rawHost.unicodeScalars.contains(where:{$0.value>127})||host.split(separator:".").contains(where:{$0.hasPrefix("xn--")}){found.append(("URL-003",evidenceHost))}
  if v6||v4{found.append(("URL-004",evidenceHost))}
  if shorts.contains(host){found.append(("URL-005",evidenceHost))}
  if scheme=="http"{found.append(("URL-006",String(text[..<schemeEnd.lowerBound])))}
  let catalog=try Contract.object("rules"),rules=catalog["rules"] as! [[String:Any]]
  var signals:[Signal]=[],guidance:[String]=[]
  for (id,evidence) in found {
   guard let rule=rules.first(where:{$0["id"] as? String==id}),
    let type=rule["signal_type"] as? String,let explanation=rule["explanation"] as? String,
    let codes=rule["guidance_codes"] as? [String] else{throw VNError.invalidResponse}
   signals.append(Signal(type:type,evidence_text:evidence,explanation:explanation))
   for code in codes where !guidance.contains(code){guidance.append(code)}
  }
  let assessment=found.contains(where:{["URL-001","URL-002"].contains($0.0)}) ? "MEDIUM":found.isEmpty ? "LOW":"INCONCLUSIVE"
  let request=AnalysisRequest(content:text,inputType:"URL")
  var characterNotes:[String]=[]
  if !v6 && !v4 {
   let report:CharacterReport
   if rawHost.unicodeScalars.contains(where:{$0.value>127}){report=try CharacterInspector.inspect(rawHost,asciiHost:host,references:refs)}
   else{report=try CharacterInspector.hostname(host,references:refs)}
   characterNotes=CharacterInspector.notes(report)
  }
  let response=AnalysisResponse(request_id:request.request_id,processing_status:"COMPLETED",assessment:assessment,
   signals:signals,recommendation_codes:found.isEmpty ? ["LOW_CAVEAT","URL_LIMITATION"]:Array(guidance.prefix(3)),
   limitations:["Chỉ phân tích chuỗi URL, không truy cập website, không xác minh đích hoặc độ an toàn."] + characterNotes,
   engine_version:"url-local-1.2",rule_version:Contract.version,schema_version:"1.0",prompt_version:"none",error_code:nil)
  try Contract.validate(response,request:request)
  return LocalURLResult(response:response,host:host)
 }
}

