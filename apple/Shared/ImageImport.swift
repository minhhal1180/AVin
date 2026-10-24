import Foundation
import Vision
import ImageIO
import UniformTypeIdentifiers
import PhotosUI
import SwiftUI

enum ImportFailure:LocalizedError {
 case invalid,tooLarge,noText,language,timeout
 var errorDescription:String? {
  switch self{
  case .invalid:return "Chọn một ảnh JPEG, PNG hoặc WebP hợp lệ."
  case .tooLarge:return "Ảnh vượt 20 MiB hoặc 40 megapixel."
  case .noText:return "Không nhận được chữ. Hãy chọn ảnh rõ hơn."
  case .language:return "Vision trên thiết bị chưa hỗ trợ tiếng Việt cho cấu hình này."
  case .timeout:return "Nhận ảnh hoặc OCR quá 15 giây. Hãy thử lại."
  }
 }
}

// A single monotonic deadline covers provider loading, bounded reading and OCR.
// Cancellation handlers registered after completion are cancelled immediately.
final class ImportOperation {
 private let lock=NSLock()
 private var finished=false
 private var cancellations:[()->Void]=[]
 private let deadline=DispatchTime.now()+15
 private let done:(Result<String,Error>)->Void
 init(done:@escaping(Result<String,Error>)->Void){
  self.done=done
  DispatchQueue.global().asyncAfter(deadline:deadline){[weak self] in self?.finish(.failure(ImportFailure.timeout))}
 }
 func check()throws {
  lock.lock();let stopped=finished;lock.unlock()
  if stopped{throw CancellationError()}
  if DispatchTime.now()>=deadline{throw ImportFailure.timeout}
 }
 func onCancel(_ action:@escaping()->Void){
  lock.lock();if finished{lock.unlock();action()}else{cancellations.append(action);lock.unlock()}
 }
 func finish(_ result:Result<String,Error>){
  lock.lock();guard !finished else{lock.unlock();return};finished=true
  let actions=cancellations;cancellations=[];lock.unlock()
  actions.forEach{$0()}
  DispatchQueue.main.async{self.done(result)}
 }
 func cancel(){finish(.failure(CancellationError()))}
}

enum ImageImport {
 static func read(_ url:URL,operation:ImportOperation)throws->Data {
  let h=try FileHandle(forReadingFrom:url);defer{try? h.close()};var data=Data()
  while true {
   try operation.check()
   guard let chunk=try h.read(upToCount:8192),!chunk.isEmpty else{break}
   guard data.count+chunk.count<=20*1024*1024 else{throw ImportFailure.tooLarge};data.append(chunk)
  }
  return data
 }
 private static func recognize(_ data:Data,operation:ImportOperation) {
  DispatchQueue.global(qos:.userInitiated).async {
   do{
    try operation.check()
    guard data.count<=20*1024*1024 else{throw ImportFailure.tooLarge}
    guard let source=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
      let type=CGImageSourceGetType(source) as String?,["public.jpeg","public.png","org.webmproject.webp"].contains(type),
      CGImageSourceGetCount(source)==1,
      let props=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
      let w=props[kCGImagePropertyPixelWidth] as? Int,let h=props[kCGImagePropertyPixelHeight] as? Int,w>0,h>0 else{throw ImportFailure.invalid}
    guard w<=40_000_000/h else{throw ImportFailure.tooLarge}
    let options:[CFString:Any]=[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:2048,kCGImageSourceShouldCacheImmediately:true]
    try operation.check()
    guard let image=CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary)else{throw ImportFailure.invalid}
    try operation.check()
    let request=VNRecognizeTextRequest();request.recognitionLevel = .accurate
    let supported=try request.supportedRecognitionLanguages()
    guard supported.contains("vi-VN") else{throw ImportFailure.language}
    request.recognitionLanguages=["vi-VN","en-US"].filter{supported.contains($0)};request.usesLanguageCorrection=true
    operation.onCancel{request.cancel()}
    try operation.check()
    try VNImageRequestHandler(cgImage:image).perform([request])
    try operation.check()
    let text=(request.results ?? []).compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n")
    guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw ImportFailure.noText}
    operation.finish(.success(text))
   }catch{operation.finish(.failure(error))}
  }
 }
 @discardableResult static func provider(_ provider:NSItemProvider,done:@escaping(Result<String,Error>)->Void)->ImportOperation {
  let operation=ImportOperation(done:done)
  let progress=provider.loadFileRepresentation(forTypeIdentifier:UTType.image.identifier){url,error in
   do{
    try operation.check()
    guard let url=url else{throw error ?? ImportFailure.invalid}
    // The provider's temporary URL is valid only inside this callback.
    let data=try read(url,operation:operation)
    try operation.check()
    recognize(data,operation:operation)
   }catch{operation.finish(.failure(error))}
  }
  operation.onCancel{progress.cancel()}
  return operation
 }
}

struct ImagePicker:UIViewControllerRepresentable {
 let selected:(NSItemProvider?)->Void
 func makeCoordinator()->Coordinator{Coordinator(selected:selected)}
 func makeUIViewController(context:Context)->PHPickerViewController{var c=PHPickerConfiguration();c.selectionLimit=1;c.filter = .images;let p=PHPickerViewController(configuration:c);p.delegate=context.coordinator;return p}
 func updateUIViewController(_ uiViewController:PHPickerViewController,context:Context){}
 final class Coordinator:NSObject,PHPickerViewControllerDelegate {
  let selected:(NSItemProvider?)->Void
  init(selected:@escaping(NSItemProvider?)->Void){self.selected=selected}
  func picker(_ picker:PHPickerViewController,didFinishPicking results:[PHPickerResult]){selected(results.first?.itemProvider)}
 }
}
