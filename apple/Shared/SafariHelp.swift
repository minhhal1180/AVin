import SwiftUI

struct SafariHelp:View {
 @Environment(\.dismiss) private var dismiss
 @Environment(\.openURL) private var openURL
 var firstRun=false
 var body:some View {
  NavigationStack {
   ScrollView {VStack(alignment:.leading,spacing:24){
    Label(firstRun ? "Bật kiểm tra nhanh":"Tô đen → Kiểm tra",systemImage:"safari").font(.title2.bold()).accessibilityAddTraits(.isHeader)
    Text("Bạn quyết định bật tiện ích và cấp quyền trong Safari.").foregroundStyle(.secondary)
    Button{openURL(URL(string:"https://support.apple.com/guide/iphone/iphab0432bf6/ios")!)}label:{Label("Mở hướng dẫn Safari",systemImage:"arrow.up.right.square").frame(maxWidth:.infinity,minHeight:48)}.buttonStyle(.borderedProminent)
    step(1,title:"Bật VNAnvia Safari",symbol:"switch.2",detail:"Trong Safari: menu trang → Quản lý phần mở rộng → bật VNAnvia Safari. Hoặc mở Cài đặt → Ứng dụng → Safari → Phần mở rộng.")
    step(2,title:"Cho phép trên website",symbol:"hand.raised",detail:"Mở VNAnvia trong menu Safari → “Cho phép trên website này”. Xác nhận lời nhắc của Safari rồi tải lại trang nếu cần.")
    step(3,title:"Chọn đoạn và chạm nút",symbol:"text.cursor",detail:"Tô đen văn bản → chạm “Kiểm tra đoạn này”. Xem lại trong VNAnvia; chỉ gửi AI khi bạn đồng ý.")
    DisclosureGroup("Không thấy VNAnvia Safari?"){
     VStack(alignment:.leading,spacing:12){
      Text("Nút hướng dẫn mở trình duyệt mặc định. Hãy mở Safari để bật tiện ích trong menu trang; VNAnvia không tự bật hoặc tự cấp quyền.")
      Text("Bản cài cần giữ SafariWebExtension.appex. Công cụ sideload có thể đã bỏ tiện ích khi ký; hãy kiểm tra tùy chọn giữ extension.")
      Text("Apple yêu cầu Developer Program để thử Safari extension trên iPhone. Chưa bảo đảm phần này hoạt động với Apple ID miễn phí.")
      Text("Bạn vẫn có thể chọn văn bản → Chia sẻ → Kiểm tra bằng VNAnvia nếu ứng dụng nguồn cung cấp nội dung.")
      Link("Hướng dẫn Safari của Apple",destination:URL(string:"https://support.apple.com/guide/iphone/iphab0432bf6/ios")!).frame(minHeight:44)
     }.font(.footnote).foregroundStyle(.secondary).padding(.top,8)
    }
   }.padding(24)}
   .navigationTitle("Kiểm tra trong Safari").navigationBarTitleDisplayMode(.inline)
   .toolbar{ToolbarItem(placement:.topBarTrailing){Button(firstRun ? "Để sau":"Xong"){dismiss()}.frame(minHeight:44)}}
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
