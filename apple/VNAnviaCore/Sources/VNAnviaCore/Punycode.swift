import Foundation
// RFC3492 decoding for validation only; no resolver or network fallback.
enum Punycode {
 static func decode(_ label:String)->String? {
  guard label.hasPrefix("xn--") else{return nil}
  let input=Array(label.dropFirst(4).utf8);var output:[UInt32]=[]
  var pos=0,n=128,index=0,bias=72
  if let dash=input.lastIndex(of:45){
   guard input[..<dash].allSatisfy({$0<128}) else{return nil}
   output=input[..<dash].map{UInt32($0)};pos=dash+1
  }
  func adapt(_ value:Int,_ count:Int,_ first:Bool)->Int{
   var d=first ? value/700:value/2;d+=d/count;var k=0
   while d>455{d/=35;k+=36};return k+36*d/(d+38)
  }
  while pos<input.count {
   let old=index;var weight=1,k=36
   while true {
    guard pos<input.count else{return nil}
    let c=input[pos];pos+=1
    let digit:Int
    if (97...122).contains(c){digit=Int(c-97)}
    else if (48...57).contains(c){digit=Int(c-48)+26}
    else{return nil}
    guard digit<=(Int.max-index)/weight else{return nil};index+=digit*weight
    let t=k<=bias ? 1:k>=bias+26 ? 26:k-bias
    if digit<t{break}
    guard weight<=Int.max/(36-t),k<Int.max-36 else{return nil};weight*=36-t;k+=36
   }
   let count=output.count+1;bias=adapt(index-old,count,old==0)
   guard n<=0x10ffff-index/count else{return nil};n+=index/count;index%=count
   guard let scalar=UnicodeScalar(n),scalar.value>=160,![0xdf,0x3c2,0x200c,0x200d,0x3002].contains(n),!(0xff00...0xffef).contains(n) else{return nil}
   output.insert(scalar.value,at:index);index+=1
  }
  guard output.contains(where:{$0>127}) else{return nil}
  let scalars=output.compactMap(UnicodeScalar.init)
  guard scalars.count==output.count,let first=scalars.first,!CharacterSet.nonBaseCharacters.contains(first) else{return nil}
  let s=String(String.UnicodeScalarView(scalars))
  guard Contract.isNFC(s) else{return nil}
  return s
 }
}

