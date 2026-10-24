import SwiftUI

struct SafariHelp:View {
 @Environment(\.dismiss) private var dismiss
 var body:some View {
  NavigationStack {
   ScrollView {VStack(alignment:.leading,spacing:24){
    Label("Tô đen → Kiểm tra",systemImage:"safari").font(.title2.bold()).accessibilityAddTraits(.isHeader)
    Text("Bật tiện ích một lần, rồi chọn đoạn cần kiểm chứng trên trang.").foregroundStyle(.secondary)
    step(1,title:"Bật VNAnvia Safari",symbol:"switch.2",detail:"Cài đặt → Ứng dụng → Safari → Tiện ích mở rộng → VNAnvia Safari → Cho phép.")
    step(2,title:"Cho phép trên website",symbol:"hand.raised",detail:"Trong Safari, mở menu trang → Tiện ích mở rộng → VNAnvia. Cấp quyền cho website rồi tải lại trang.")
    step(3,title:"Chọn đoạn và chạm nút",symbol:"text.cursor",detail:"Tô đen văn bản → chạm “Kiểm tra đoạn này”. Xem lại trong VNAnvia; chỉ gửi AI khi bạn đồng ý.")
    DisclosureGroup("Không thấy VNAnvia Safari?"){
     VStack(alignment:.leading,spacing:12){
      Text("Bản cài cần giữ SafariWebExtension.appex. Công cụ sideload có thể đã bỏ tiện ích khi ký; hãy kiểm tra tùy chọn giữ extension.")
      Text("Apple yêu cầu Developer Program để thử Safari extension trên iPhone. Chưa bảo đảm phần này hoạt động với Apple ID miễn phí.")
      Text("Bạn vẫn có thể chọn văn bản → Chia sẻ → Kiểm tra bằng VNAnvia nếu ứng dụng nguồn cung cấp nội dung.")
      Link("Hướng dẫn Safari của Apple",destination:URL(string:"https://support.apple.com/guide/iphone/iphab0432bf6/ios")!).frame(minHeight:44)
     }.font(.footnote).foregroundStyle(.secondary).padding(.top,8)
    }
   }.padding(24)}
   .navigationTitle("Kiểm tra trong Safari").navigationBarTitleDisplayMode(.inline)
   .toolbar{ToolbarItem(placement:.topBarTrailing){Button("Xong"){dismiss()}.frame(minHeight:44)}}
  }
 }
 private func step(_ number:Int,title:String,symbol:String,detail:String)->some View {
  HStack(alignment:.top,spacing:16){
   Text("\(number)").font(.headline.monospacedDigit()).frame(width:36,height:36).background(Color(.tertiarySystemFill),in:Circle()).accessibilityHidden(true)
   VStack(alignment:.leading,spacing:8){
    Label(title,systemImage:symbol).font(.headline)
    Text(detail).font(.subheadline).foregroundStyle(.secondary)
   }.frame(maxWidth:.infinity,alignment:.leading)
  }.padding(16).background(Color(.secondarySystemBackground),in:RoundedRectangle(cornerRadius:16)).accessibilityElement(children:.combine)
 }
}
