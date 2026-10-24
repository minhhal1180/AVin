import Foundation

public struct CharacterObservation {
 public let character:String, codePoint:String, ascii:String, script:String
}
public struct CharacterReport {
 public let suspicious:Bool, unicodeHost:String, asciiHost:String, lookalikeHost:String, referenceMatch:String?
 public let characters:[CharacterObservation]
}
public enum CharacterInspector {
 public static func inspect(_ unicodeHost:String,asciiHost:String,references:[String]=[])throws->CharacterReport {
  let object=try Contract.object("confusables")
  guard let mappings=object["mappings"] as? [String:[String:String]] else{throw VNError.invalidResponse}
  let host=unicodeHost.hasSuffix(".") ? String(unicodeHost.dropLast()):unicodeHost
  var hits:[Unicode.Scalar]=[]
  for label in host.split(separator:".",omittingEmptySubsequences:false) {
   let points=Array(label.unicodeScalars)
   let mapped=points.filter { mappings[String($0)] != nil }
   let latin=points.contains{(65...90).contains($0.value)||(97...122).contains($0.value)}
   let whole=points.count>=3 && points.allSatisfy{$0.value<128 || mappings[String($0)] != nil}
   if !mapped.isEmpty && (latin || whole){hits.append(contentsOf:mapped)}
  }
  let lookalike=host.unicodeScalars.map{mappings[String($0)]?["ascii"] ?? String($0).lowercased()}.joined()
  var reference=references.first{lookalike==$0 || lookalike.hasSuffix("."+$0) || lookalike.hasPrefix($0+".") || lookalike.contains("."+$0+".")}
  if let r=reference,asciiHost==r || asciiHost.hasSuffix("."+r){reference=nil}
  var chars:[CharacterObservation]=[],seen=Set<UInt32>()
  for c in hits where !seen.contains(c.value) && chars.count<4 {
   seen.insert(c.value);let entry=mappings[String(c)]!
   chars.append(CharacterObservation(character:String(c),codePoint:String(format:"U+%04X",c.value),ascii:entry["ascii"]!,script:entry["script"]!))
  }
  return CharacterReport(suspicious:!hits.isEmpty,unicodeHost:host,asciiHost:asciiHost,lookalikeHost:lookalike,referenceMatch:hits.isEmpty ? nil:reference,characters:chars)
 }
 public static func hostname(_ asciiHost:String,references:[String]=[])throws->CharacterReport {
  let unicode=asciiHost.split(separator:".").map{label in label.hasPrefix("xn--") ? (Punycode.decode(String(label)) ?? String(label)):String(label)}.joined(separator:".")
  return try inspect(unicode,asciiHost:asciiHost,references:references)
 }
 public static func notes(_ report:CharacterReport)->[String] {
  guard report.suspicious else{return []}
  let details=report.characters.map{"\($0.codePoint) \($0.script) → \($0.ascii)"}.joined(separator:"; ")
  var notes=["Ký tự dễ nhầm Latin: \(details). Cần đối chiếu tên miền; chưa xác nhận giả mạo.","Tên miền Unicode: "+report.unicodeHost,"Tên miền ASCII thực tế: "+report.asciiHost]
  if let r=report.referenceMatch{notes.append("Gần giống domain tham chiếu: "+r+"; là tên miền khác, cần kiểm chứng độc lập.")}
  return notes.map{String(String.UnicodeScalarView($0.unicodeScalars.prefix(300)))}
 }
}
