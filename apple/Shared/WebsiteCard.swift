import SwiftUI
import VNAnviaCore

struct WebsiteCard:View {
 let url:String,ready:Bool
 @State private var consent=false,busy=false
 @State private var request:WebsiteRequest?
 @State private var result:WebsiteResult?
 @State private var message=""
 @State private var generation=0
 @State private var task:Task<Void,Never>?
 @Environment(\.scenePhase) private var scene
 var body:some View {
  VStack(alignment:.leading,spacing:12){
   Text("Kiểm tra website nâng cao").font(.headline)
   Text("Mở trang trong sandbox; phân tích ảnh cùng nội dung. Kiểm tra URL cục bộ vẫn tách riêng.").font(.footnote)
   Button("Xem website trong sandbox"){
    do{let r=WebsiteRequest(url:Contract.trim(url));try r.validate();request=r;consent=true;message=""}
    catch{message="Chỉ nhận URL HTTPS công khai, cổng443 và tên miền ASCII/Punycode."}
   }.disabled(!ready || busy)
   if !ready{Text("Kết nối dịch vụ để dùng kiểm tra nâng cao.").font(.footnote)}
   if busy{ProgressView("Đang chụp và phân tích…");Button("Hủy kiểm tra website"){cancel()}}
   if !message.isEmpty{Text(message).font(.footnote)}
   if let r=result,r.processing_status=="COMPLETED"{
    Text(heading(r.inspection_status)).font(.headline)
    Text("Nhận xét trong phần đã quan sát; chưa xác minh website an toàn.").font(.footnote)
    Text("URL cuối: "+(r.final_url ?? ""))
    ForEach(Array(r.findings.enumerated()),id:\.offset){_,f in Text(f.severity=="WARNING" ? "Dấu hiệu cần kiểm chứng":"Thông tin quan sát — chưa kết luận nguy cơ").font(.caption);Text(f.explanation);Text("“"+f.evidence_text+"”");Text("Nguồn: "+checkName(f.source)).font(.caption)}
    DisclosureGroup("Phạm vi đã kiểm tra"){ForEach(r.checks,id:\.name){c in Text(checkName(c.name)+" · "+(c.status=="CHECKED" ? "Đã kiểm trong snapshot":c.status=="PARTIAL" ? "Kiểm một phần":"Chưa thu thập được")).font(.headline);Text(c.note).font(.footnote)}}
    DisclosureGroup("Giới hạn của kết quả"){ForEach(r.limitations,id:\.self){Text($0).font(.footnote)}}
   }
  }.padding().background(.quaternary,in:RoundedRectangle(cornerRadius:16))
  .sheet(isPresented:$consent){NavigationStack{ScrollView{VStack(alignment:.leading,spacing:20){
   Text(request?.url ?? "").textSelection(.enabled)
   Text("Sandbox sẽ liên hệ website và tải tài nguyên; có thể kích hoạt link theo dõi. Xóa mã riêng tư trong URL trước khi gửi.")
   Text("Backend ưu tiên Gemini (Google), dự phòng Groq khi hết quota hoặc dịch vụ tạm lỗi. Cùng ảnh chụp, nội dung, HTML đã làm sạch, JavaScript và tóm tắt đích request có thể gửi tới cả hai.")
   Text("Chỉ dùng trang mô phỏng. Google Free Tier có thể dùng dữ liệu để cải thiện sản phẩm và cho người rà soát; không gửi dữ liệu cá nhân, bí mật hoặc nhạy cảm. Không đăng nhập, gửi biểu mẫu hay lưu lịch sử. Hủy không thu hồi dữ liệu đã gửi. Chính sách website-2026-10-24.1.")
   Button("Đồng ý mở và phân tích"){submit()}.buttonStyle(.borderedProminent)
   Button("Từ chối"){consent=false;request=nil}
  }.padding()}.navigationTitle("Cho phép mở website?").toolbar{Button("Đóng"){consent=false;request=nil}}}}
  .onChange(of:ready){_,_ in cancel()}.onChange(of:scene){_,s in if s != .active{cancel()}}.onDisappear{cancel()}
 }
 private func cancel(){generation+=1;task?.cancel();task=nil;busy=false;consent=false;request=nil;result=nil}
 private func submit(){guard let r=request,Contract.trim(url)==r.url else{return};consent=false;busy=true;generation+=1;let g=generation
  task=Task{do{let value=try await NativeAccess.shared.website(r,owner:"website-native");guard g==generation else{return};result=value;busy=false
   if value.processing_status=="FAILED"{message="Chưa có đánh giá website: "+(value.error_code ?? "WEBSITE_UNAVAILABLE")}
  }catch{guard g==generation else{return};busy=false;message="Không hoàn tất kiểm tra website. Sandbox hoặc kết nối chưa sẵn sàng."}}
 }
 private func heading(_ status:String)->String{["RISK_INDICATORS":"Website có dấu hiệu cần kiểm chứng","NO_RISK_INDICATORS":"Chưa ghi nhận dấu hiệu đáng ngờ trong phần đã kiểm","INSUFFICIENT_DATA":"Chưa đủ dữ liệu để đánh giá website"][status] ?? "Không hoàn tất kiểm tra website"}
 private func checkName(_ name:String)->String{["SCRIPT":"JavaScript","FORM_ACTION":"Đích biểu mẫu","LINK":"Đích liên kết","DOM_TEXT":"Nội dung hiển thị","HTML_SOURCE":"Mã HTML","FORMS":"Biểu mẫu","LINKS":"Liên kết","JAVASCRIPT":"JavaScript","NETWORK":"Request khi tải trang","SCREENSHOT":"Ảnh chụp"][name] ?? name}
}
