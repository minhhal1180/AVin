import SwiftUI
import UniformTypeIdentifiers
import VNAnviaCore

@MainActor final class AnalysisModel:ObservableObject {
 @Published var draft="" {didSet{invalidate()}}
 @Published var type="TEXT" {didSet{invalidate()}}
 @Published var token=""
 @Published var remember=false
 @Published var capabilities:Capabilities?
 @Published var connecting=false
 @Published var settings=false
 @Published var picker=false
 @Published var busy=false
 @Published var consent:AnalysisRequest?
 @Published var review:String?
 @Published var result:AnalysisResponse?
 @Published var local:LocalURLResult?
 @Published var showingOutcome=false
 @Published var failureCode:String?
 @Published var message=""
 private let analyze:(AnalysisRequest)async throws->AnalysisResponse
 private var generation=0,connectionGeneration=0
 private var task:Task<Void,Never>?
 private var expiryTask:Task<Void,Never>?
 private var importOperation:ImportOperation?
 private var pickerGeneration=0
 private var restored=false
 init(analyze:@escaping(AnalysisRequest)async throws->AnalysisResponse = {try await NativeAccess.shared.analyze($0)}){self.analyze=analyze}
 func restore(){guard !restored else{return};restored=true;let g=connectionGeneration
  connecting=true
  Task{do{let restored=try await NativeAccess.shared.restore();guard g==connectionGeneration else{return}
   let c:Capabilities;if let existing=restored{c=existing}else{c=try await NativeAccess.shared.bootstrap()}
   await connected(c,generation:g)
  }catch{guard g==connectionGeneration else{return};connecting=false;message="Dịch vụ chưa sẵn sàng. URL và OCR vẫn dùng được trên thiết bị."}}
 }
 func invalidate(){generation+=1;task?.cancel();task=nil;importOperation?.cancel();importOperation=nil;consent=nil;review=nil;result=nil;local=nil;failureCode=nil;showingOutcome=false;message="";busy=false}
 func forget(){invalidate();connectionGeneration+=1;expiryTask?.cancel();expiryTask=nil;connecting=false;capabilities=nil;token="";remember=false;Task{await NativeAccess.shared.forget()}}
 func connect(){
  invalidate();connectionGeneration+=1;expiryTask?.cancel();let g=connectionGeneration;let r=remember;connecting=true;capabilities=nil
  Task{do{let c=try await NativeAccess.shared.bootstrap(remember:r);await connected(c,generation:g);guard g==connectionGeneration else{return};token="";message="Đã kết nối. Bạn có thể tiếp tục."}
   catch{guard g==connectionGeneration else{return};connecting=false;message="Dịch vụ chưa sẵn sàng. Hãy thử lại; bạn không cần khóa API."}}
 }
 private func connected(_ c:Capabilities,generation g:Int)async {
  let saved=await NativeAccess.shared.remembers()
  let expiry=await NativeAccess.shared.expiryDate()
  guard g==connectionGeneration else{return};capabilities=c;remember=saved;connecting=false
  expiryTask?.cancel()
  if let expiry=expiry{expiryTask=Task{[weak self] in
   do{try await Task.sleep(nanoseconds:UInt64(max(0,expiry.timeIntervalSinceNow)*1_000_000_000))}catch{return}
   guard let self=self,!Task.isCancelled,g==self.connectionGeneration else{return};self.forget();self.message="Phiên đã hết hạn. Hãy kết nối lại để tiếp tục."
  }}
 }
 func setRemember(_ value:Bool){let g=connectionGeneration
  Task{do{try await NativeAccess.shared.setRemember(value);let saved=await NativeAccess.shared.remembers();guard g==connectionGeneration else{return};remember=saved}
   catch{guard g==connectionGeneration else{return};remember=false;message="Chưa lưu được phiên an toàn. Phiên hiện tại vẫn chỉ ở bộ nhớ."}}
 }
 func start(){
  invalidate()
  do{let text=try Contract.input(draft,type:type)
   if type=="URL"{local=try LocalURL.analyze(text);showingOutcome=true;return}
   guard capabilities != nil else{settings=true;message="Kết nối để tiếp tục. Nội dung vẫn giữ trong phiên.";return}
   consent=AnalysisRequest(content:text)
  }catch{message="Nội dung không hợp lệ hoặc quá dài. Hãy kiểm tra và sửa lại."}
 }
 @discardableResult func submit(_ request:AnalysisRequest)->Task<Void,Never>?{
  guard consent?.request_id==request.request_id else{return nil}
  invalidate();let g=generation;busy=true;message=""
  task=Task{do{let r=try await analyze(request);guard g==generation else{return};busy=false
   if r.processing_status=="FAILED"{showFailure(r.error_code ?? "ANALYSIS_UNAVAILABLE")}else{result=r;showingOutcome=true}
  }catch{guard g==generation else{return};busy=false;showFailure((error as? VNError)?.rawValue ?? "NETWORK_UNAVAILABLE")}}
  return task
 }
 private func showFailure(_ code:String){failureCode=code;message=AnalysisFeedback.message(code);showingOutcome=true}
 func useDemo(){type="TEXT";draft=AnalysisFeedback.demoText}
 func receive(_ value:Result<String,Error>,generation:Int){
  guard generation==self.generation else{return};importOperation=nil;busy=false
  switch value{case .success(let text):review=text;case .failure(let e):message=e.localizedDescription}
 }
 func beginImage(){invalidate();pickerGeneration=generation;picker=true;message=""}
 func selectImage(_ provider:NSItemProvider?){
  picker=false
  guard pickerGeneration==generation,let provider=provider else{return}
  let g=generation;busy=true
  importOperation=ImageImport.provider(provider){[weak self] value in self?.receive(value,generation:g)}
 }
 deinit{expiryTask?.cancel();task?.cancel();importOperation?.cancel()}
}
struct AnalysisScreen:View {
 @StateObject var model=AnalysisModel()
 @FocusState private var editorFocused:Bool
 @State private var confirmDemo=false
 @Environment(\.scenePhase) private var scenePhase
 var initial:String?=nil
 var close:(()->Void)?=nil
 let teal=Color(red:0.08,green:0.42,blue:0.38)
 let labels=["LOW":"Chưa phát hiện dấu hiệu rõ ràng","MEDIUM":"Có dấu hiệu cần kiểm chứng","HIGH":"Có hành vi nguy cơ cao","INCONCLUSIVE":"Chưa đủ cơ sở đánh giá"]
 var body:some View {
  NavigationStack {
   ScrollView {VStack(alignment:.leading,spacing:24){
    HStack(spacing:12){Image("BrandIcon").resizable().frame(width:40,height:40).clipShape(RoundedRectangle(cornerRadius:12)).accessibilityHidden(true);Text("VNAnvia").font(.headline)}
    Text("Kiểm tra trước khi tin.").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
    Text("Chọn nội dung bạn muốn kiểm chứng.").foregroundStyle(.secondary)
    HStack(spacing:12){sourceTile("Văn bản",symbol:"text.alignleft",selected:model.type=="TEXT"){model.type="TEXT"};sourceTile("URL",symbol:"link",selected:model.type=="URL"){model.type="URL"};sourceTile("Ảnh",symbol:"photo",selected:false){model.beginImage()}}
    if model.type=="TEXT" && model.capabilities?.real_content_enabled==false{
     GroupBox{VStack(alignment:.leading,spacing:12){Label("Chế độ thử nghiệm",systemImage:"testtube.2").font(.headline);Text("Chỉ nhận mẫu mô phỏng đã duyệt.").font(.subheadline).foregroundStyle(.secondary);Button("Dùng mẫu OTP",action:requestDemo).frame(minHeight:44)}}
    }
    VStack(alignment:.leading,spacing:8){
     Text("Nội dung cần kiểm tra").font(.headline)
     TextEditor(text:$model.draft).focused($editorFocused).frame(minHeight:180).padding(8).background(.background,in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(.secondary)).accessibilityLabel("Nội dung cần kiểm tra")
     Text("\(model.draft.unicodeScalars.count) / \(model.type == "TEXT" ? 4000:2048) ký tự").font(.caption).foregroundStyle(.secondary)
    }
    Text("OCR cục bộ · Chỉ gửi văn bản sau đồng ý.").font(.footnote).foregroundStyle(.secondary)
    Button("Kiểm tra nội dung"){editorFocused=false;model.start()}.buttonStyle(.borderedProminent).frame(maxWidth:.infinity,minHeight:48).disabled(model.draft.isEmpty||model.busy||(model.connecting && model.type=="TEXT"))
    if model.type=="URL" && !model.busy{WebsiteCard(url:model.draft,ready:model.capabilities != nil).id(model.draft+String(model.capabilities?.token_expires_at ?? 0))}
    if model.busy{ProgressView("Đang xử lý…");Button("Hủy"){model.invalidate()}.frame(minHeight:44)}
    if !model.message.isEmpty{Text(model.message).foregroundStyle(.secondary).accessibilityLabel("Thông báo: "+model.message)}
    if model.result != nil || model.local != nil{Button("Xem kết quả"){model.showingOutcome=true}.frame(minHeight:44)}
    DisclosureGroup("Quyền riêng tư & giới hạn"){Text("LOW không chứng nhận an toàn. HIGH không xác nhận tội phạm. Không lưu lịch sử hoặc bản nháp. Ảnh OCR không gửi tới backend.").font(.footnote).foregroundStyle(.secondary)}
   }.padding(24)}.scrollDismissesKeyboard(.interactively)
   .navigationTitle("VNAnvia").navigationBarTitleDisplayMode(.inline)
   .toolbar{ToolbarItem(placement:.topBarTrailing){Button("Dịch vụ"){editorFocused=false;model.settings=true}};ToolbarItemGroup(placement:.keyboard){Spacer();Button("Xong"){editorFocused=false}};if let close=close{ToolbarItem(placement:.topBarLeading){Button("Đóng"){model.invalidate();close()}}}}
   .navigationDestination(isPresented:$model.showingOutcome){outcome}
   .confirmationDialog("Thay nội dung hiện tại bằng mẫu thử?",isPresented:$confirmDemo,titleVisibility:.visible){Button("Dùng mẫu OTP"){model.useDemo()};Button("Giữ nội dung",role:.cancel){}}
   .onChange(of:model.showingOutcome){_,shown in if shown{editorFocused=false}}
   .sheet(isPresented:$model.settings){connection}
   .sheet(isPresented:$model.picker){ImagePicker(selected:model.selectImage)}
   .sheet(item:Binding(get:{model.consent.map{ConsentItem(request:$0)}},set:{if $0==nil{model.consent=nil}})){item in consent(item.request)}
   .sheet(isPresented:Binding(get:{model.review != nil},set:{if !$0{model.review=nil}})){NavigationStack{VStack(alignment:.leading,spacing:16){
    Text("OCR có thể nhận sai. Bằng chứng chỉ đối chiếu với chữ bạn xác nhận.").font(.footnote)
    TextEditor(text:Binding(get:{model.review ?? ""},set:{model.review=$0})).accessibilityLabel("Sửa chữ nhận được")
    Button("Dùng văn bản này"){let text=model.review ?? "";model.draft=text;model.type="TEXT";model.review=nil}.buttonStyle(.borderedProminent).frame(minHeight:44)
   }.padding(24).navigationTitle("Xem và sửa chữ").toolbar{Button("Hủy"){model.review=nil}}}}
   .onAppear{model.restore();if let initial=initial,model.draft.isEmpty{model.draft=initial}}
   .overlay{if scenePhase != .active{Color(.systemBackground).overlay(Text("VNAnvia").font(.title))}}
  }.tint(teal).privacySensitive()
 }
 func requestDemo(){editorFocused=false;if Contract.trim(model.draft).isEmpty{model.useDemo()}else{confirmDemo=true}}
 var outcome:some View{ScrollView{VStack(alignment:.leading,spacing:24){
  if let code=model.failureCode{
   Label("Chưa thể phân tích",systemImage:"exclamationmark.circle").font(.title2.bold()).accessibilityAddTraits(.isHeader)
   Text(model.message)
   if code=="CONSENT_REQUIRED"{Button("Dùng mẫu OTP",action:requestDemo).buttonStyle(.borderedProminent).frame(minHeight:44)}
   Button("Quay lại nội dung"){model.showingOutcome=false}.frame(minHeight:44)
  }else if let r=model.result{resultView(r)}else if let r=model.local{Text("Máy chủ: "+r.host).textSelection(.enabled);resultView(r.response)}
 }.padding(24)}.navigationTitle(model.failureCode==nil ? "Kết quả kiểm tra":"Chưa thể phân tích").navigationBarTitleDisplayMode(.inline)}
 func sourceTile(_ title:String,symbol:String,selected:Bool,action:@escaping()->Void)->some View{
  Button(action:action){VStack(alignment:.leading,spacing:12){Image(systemName:symbol).font(.title2);Text(title).font(.subheadline.weight(.semibold))}.frame(maxWidth:.infinity,minHeight:74,alignment:.leading).padding(12).background(selected ? teal.opacity(0.12):Color(.secondarySystemBackground),in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(selected ? teal:Color(.separator),lineWidth:selected ? 2:1))}.buttonStyle(.plain).foregroundStyle(teal)
 }
 struct ConsentItem:Identifiable {let request:AnalysisRequest;var id:String{request.request_id}}
 func consent(_ request:AnalysisRequest)->some View{
  NavigationStack{ScrollView{VStack(alignment:.leading,spacing:20){
   Text("Văn bản qua HTTPS edge Cloudflare và VPS VNAnvia. Backend ưu tiên Gemini (Google), dự phòng Groq khi hết quota hoặc dịch vụ tạm lỗi. Cùng văn bản đã xác nhận có thể gửi tới cả hai. Ảnh OCR gốc không được gửi.")
   Text(request.content).padding().background(.quaternary,in:RoundedRectangle(cornerRadius:12)).textSelection(.enabled)
   Text("Chỉ dùng dữ liệu mô phỏng. Google Free Tier có thể dùng dữ liệu để cải thiện sản phẩm và cho người rà soát; không gửi dữ liệu cá nhân, bí mật hoặc nhạy cảm. Hủy không thu hồi dữ liệu đã gửi. Chính sách "+Contract.privacy).font(.footnote)
   Button("Đồng ý gửi lần này"){model.submit(request)}.buttonStyle(.borderedProminent).frame(minHeight:44)
   Button("Từ chối"){model.consent=nil}.frame(minHeight:44)
  }.padding(24)}.navigationTitle("Xem lại trước khi gửi").toolbar{Button("Đóng"){model.consent=nil}}}
 }
 var connection:some View{NavigationStack{Form{
  Section("Dịch vụ phân tích"){Text("Tự kết nối. Không cần khóa API, mã mời hoặc tài khoản.")
   Toggle("Nhớ phiên tạm tối đa 8 giờ",isOn:Binding(get:{model.remember},set:model.setRemember)).disabled(model.connecting || model.capabilities==nil)
   Button(model.connecting ? "Đang kết nối…":"Thử kết nối lại"){model.connect()}.disabled(model.connecting)
   Button("Kết thúc phiên",role:.destructive){model.forget()}
   Text(model.message)
  }
  Section("Quyền riêng tư"){Text("Khóa Gemini và Groq chỉ trên máy chủ. Ưu tiên Gemini, dự phòng Groq khi hết quota hoặc dịch vụ tạm lỗi. Chỉ dùng dữ liệu mô phỏng; Google Free Tier có thể dùng dữ liệu để cải thiện sản phẩm và cho người rà soát. Mỗi target giữ phiên riêng; ảnh, draft và kết quả không lưu. Chính sách "+Contract.privacy)}
 }.navigationTitle("Dịch vụ").toolbar{Button("Xong"){model.settings=false}}}}
 func resultView(_ r:AnalysisResponse)->some View{VStack(alignment:.leading,spacing:16){
  Text(labels[r.assessment ?? ""] ?? "Chưa đánh giá").font(.title2.bold()).accessibilityAddTraits(.isHeader)
  let characterNotes=r.limitations.filter{$0.hasPrefix("Ký tự dễ nhầm") || $0.hasPrefix("Tên miền Unicode:") || $0.hasPrefix("Tên miền ASCII thực tế:") || $0.hasPrefix("Gần giống domain tham chiếu:")}
  if !characterNotes.isEmpty{GroupBox("Kiểm tra ký tự tên miền"){VStack(alignment:.leading){ForEach(characterNotes,id:\.self){Text($0).font(.footnote)}}}}
  ForEach(r.signals,id:\.type){s in VStack(alignment:.leading,spacing:8){Text(s.explanation).font(.headline);Text("“"+s.evidence_text+"”").padding().background(.quaternary,in:RoundedRectangle(cornerRadius:12))}}
  Text("Bước tiếp theo").font(.headline)
  let guidance=(try? Contract.object("rules")["guidance"] as? [String:String]) ?? [:]
  ForEach(r.recommendation_codes,id:\.self){Text(guidance[$0] ?? $0)}
  ForEach(r.limitations.filter{!characterNotes.contains($0)},id:\.self){Text($0).font(.footnote).foregroundStyle(.secondary)}
 }}
}

