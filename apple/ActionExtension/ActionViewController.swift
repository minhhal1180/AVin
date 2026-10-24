import UIKit
import SwiftUI
import UniformTypeIdentifiers
import VNAnviaCore
final class ActionViewController:UIViewController {
 private var generation=0
 private var operation:ImportOperation?
 private var analysisModel:AnalysisModel?
 override func viewDidLoad(){
  super.viewDidLoad();view.backgroundColor = .systemBackground
  let items=(extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap{$0.attachments ?? []}
  guard items.count==1,let provider=items.first else{showError("Chỉ nhận một nội dung hoặc một ảnh mỗi lần.");return}
  generation+=1;let g=generation
  let loading=UIActivityIndicatorView(style:.large);loading.center=CGPoint(x:view.bounds.midX,y:view.bounds.midY);loading.autoresizingMask=[.flexibleLeftMargin,.flexibleRightMargin,.flexibleTopMargin,.flexibleBottomMargin];view.addSubview(loading);loading.startAnimating()
  let cancel=UIButton(type:.system);cancel.setTitle("Hủy",for:.normal);cancel.frame=CGRect(x:24,y:view.bounds.height-100,width:view.bounds.width-48,height:48);cancel.autoresizingMask=[.flexibleWidth,.flexibleTopMargin];cancel.addTarget(self,action:#selector(cancelImport),for:.touchUpInside);view.addSubview(cancel)
  if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier){
   operation=ImageImport.provider(provider){[weak self] value in guard let self=self,self.generation==g else{return};self.operation=nil
    switch value{case .success(let text):self.show(text,review:true);case .failure(let e):self.showError(e.localizedDescription)}
   }
  }else{
   let isURL=provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
   let transfer=ImportOperation{[weak self] result in
    guard let self=self,self.generation==g else{return};self.operation=nil
    switch result{case .success(let text):self.show(text);case .failure:self.showError("Ứng dụng nguồn chưa cung cấp văn bản/link hợp lệ hoặc đã quá 15 giây.")}
   };operation=transfer
   let complete:(String?,Error?)->Void={value,error in
    do{
     try transfer.check()
     guard let text=value else{throw error ?? VNError.invalidInput}
     if isURL,!["http","https"].contains(URL(string:text)?.scheme?.lowercased() ?? ""){throw VNError.invalidInput}
     let checked=try Contract.input(text,type:isURL ? "URL":"TEXT")
     try transfer.check();transfer.finish(.success(checked))
    }catch{transfer.finish(.failure(error))}
   }
   let progress:Progress
   if isURL{
    progress=provider.loadObject(ofClass:NSURL.self){value,error in complete((value as? NSURL)?.absoluteString,error)}
   }else{
    progress=provider.loadObject(ofClass:NSString.self){value,error in complete(value as? String,error)}
   }
   transfer.onCancel{progress.cancel()}
  }
 }
 @objc private func cancelImport(){generation+=1;operation?.cancel();operation=nil;analysisModel?.invalidate();extensionContext?.completeRequest(returningItems:nil)}
 override func viewDidDisappear(_ animated:Bool){super.viewDidDisappear(animated);if isBeingDismissed{generation+=1;operation?.cancel();operation=nil;analysisModel?.invalidate()}}
 deinit{operation?.cancel()}
 private func show(_ text:String,review:Bool=false){
  let model=AnalysisModel();analysisModel=model
  if review{model.review=text}else{model.draft=text;model.type=["http","https"].contains(URL(string:text)?.scheme?.lowercased() ?? "") ? "URL":"TEXT"}
  let host=UIHostingController(rootView:AnalysisScreen(model:model,close:{[weak self] in self?.cancelImport()}))
  addChild(host);view.addSubview(host.view);host.view.frame=view.bounds;host.view.autoresizingMask=[.flexibleWidth,.flexibleHeight];host.didMove(toParent:self)
 }
 private func showError(_ message:String){let alert=UIAlertController(title:"Không nhận được nội dung",message:message,preferredStyle:.alert);alert.addAction(UIAlertAction(title:"Đóng",style:.cancel){[weak self]_ in self?.extensionContext?.completeRequest(returningItems:nil)});DispatchQueue.main.async{self.present(alert,animated:true)}}
}

