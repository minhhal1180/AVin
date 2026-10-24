# Cài VNAnvia lên iPhone bằng Apple ID miễn phí

Lộ trình đã chọn ngày 24/10/2026: **Codemagic build IPA → Sideloadly ký trên Windows → cài qua USB**. iPhone cần iOS 17 trở lên. Codemagic chỉ tạo IPA chưa ký; quy trình ký trực tiếp của dịch vụ yêu cầu Apple Developer Program. [Nguồn Codemagic](https://docs.codemagic.io/yaml-code-signing/signing-ios/).

Riêng Safari Web Extension, hướng dẫn chính thức của Apple yêu cầu Apple Developer Program để thử trên thiết bị; simulator được phép trước khi tham gia. Gói vẫn giữ Safari extension, nhưng Sideloadly/Apple ID miễn phí chưa được chứng minh vượt qua giới hạn này cho VNAnvia. Không xem đây là phương án bảo đảm đủ mọi chức năng Safari. [Yêu cầu Apple](https://developer.apple.com/documentation/safariservices/running-your-safari-web-extension).

## 1. Lấy đúng IPA từ Codemagic

1. Mở ứng dụng **AVin** trên Codemagic, chọn nhánh `main`, bấm nút làm mới cạnh nhánh để đọc `codemagic.yaml` mới nhất.
2. Bấm **Start new build** (lần đầu là **Start your first build**), chọn workflow **`ios-device-unsigned`**, rồi bắt đầu build. Workflow này build Release cho iPhone thật, giữ Action Extension và Safari Extension.
3. Khi build thành công, mở **Artifacts**, tải **`VNAnvia-device-unsigned.ipa`**, `build-info.json`, `ipa-validation.json` và `SHA256SUMS.txt` cùng lượt build. Trong PowerShell, chạy `Get-FileHash .\VNAnvia-device-unsigned.ipa -Algorithm SHA256` và đối chiếu checksum.

File `VNAnvia-simulator.app.zip` của workflow `ios-simulator` chỉ dành cho simulator trên Mac. IPA thiết bị phải được build riêng; đổi đuôi ZIP không tạo được app iPhone.

## 2. Ký và cài trên Windows

Tải **Sideloadly bản Windows** từ [trang chính thức](https://sideloadly.io/). Trang tải yêu cầu iTunes và iCloud bản tải từ website, có liên kết tải tương ứng. Kiểm tra bản đang cài trước; nếu là bản Microsoft Store, làm theo hướng dẫn chuyển bản của Sideloadly, không tự gỡ phần mềm hoặc xóa dữ liệu Apple khác.

1. Mở khóa iPhone, cắm cáp USB truyền dữ liệu, chọn **Tin cậy máy tính này** khi được hỏi. Kiểm tra Sideloadly nhận đúng thiết bị.
2. Trên iPhone, bật **Cài đặt → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển** nếu máy yêu cầu; khởi động lại và xác nhận theo màn hình. [FAQ Sideloadly](https://sideloadly.io/faq).
3. Kéo `VNAnvia-device-unsigned.ipa` vào Sideloadly, chọn iPhone và chế độ ký bằng Apple ID. Chỉ nhập Apple ID, mật khẩu và mã xác minh vào ứng dụng Sideloadly trên máy của bạn; không gửi vào chat, repository hoặc biến môi trường Codemagic.
4. Trong tùy chọn nâng cao, giữ **Remove Extensions tắt** và giữ cả `ActionExtension.appex`, `SafariWebExtension.appex`. Không thêm tweak hoặc tự đổi bundle ID để thử nhiều bản. [Tính năng Sideloadly](https://sideloadly.io/).
5. Bấm **Start**; chờ Sideloadly báo cài xong. Nếu iOS báo chưa tin cậy nhà phát triển, mở **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị**, chọn chứng nhận gắn với Apple ID vừa dùng, xác nhận tin cậy theo hướng dẫn của máy. Sau đó mở VNAnvia.

## 3. Thử app và hai extension

- **App:** mở VNAnvia, thử nhập văn bản, một URL và chọn ảnh để xem/sửa chữ OCR. Kiểm tra URL cục bộ trước; phân tích cloud còn phụ thuộc backend đã triển khai đúng phiên bản và consent từng lần.
- **Action Extension:** trong Notes/Safari/Photos, chọn một văn bản, link hoặc ảnh → **Chia sẻ** → **Kiểm tra bằng VNAnvia**; nếu chưa thấy, mở phần chỉnh sửa tác vụ trong bảng Chia sẻ. Nội dung nhận được phụ thuộc ứng dụng nguồn.
- **Safari Extension:** mở **Cài đặt → Ứng dụng → Safari → Tiện ích mở rộng** (iOS cũ: **Cài đặt → Safari**), bật **VNAnvia Safari**. Trên trang cần thử, mở menu tiện ích của Safari, cấp quyền cho trang rồi chủ động kiểm tra nội dung.

Đóng gói đủ extension chưa chứng minh chúng hoạt động sau khi ký miễn phí, đặc biệt với yêu cầu Program của Safari nêu trên. Nếu ký/cài báo lỗi extension, giữ lại lỗi để xử lý; không bỏ extension rồi báo toàn bộ tính năng đã đạt. Safari bỏ qua tham số application ID của `sendNativeMessage` và gửi tới native extension của app chứa nó, nên không quy lỗi native messaging chỉ từ ID gốc trong JavaScript. [Apple native messaging](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension).

## 4. Gia hạn và xử lý lỗi

Tài khoản miễn phí có hạn ký **7 ngày**, tối đa **3 app trên mỗi thiết bị**; Apple giới hạn **10 App ID trong chu kỳ 7 ngày**. App và các extension dùng ID riêng, nên tránh đổi ID qua mỗi lần cài. [Giới hạn Apple](https://developer.apple.com/help/account/basics/about-your-developer-account/).

Cài đè bằng **cùng Apple ID và bundle ID** trước khi hết hạn. Có thể bật auto-refresh trong Sideloadly; máy Windows phải chạy daemon và thấy iPhone qua USB hoặc Wi-Fi đã ghép đôi. [Hướng dẫn gia hạn](https://sideloadly.io/faq).

Nếu lỗi, giữ lại thông báo lỗi đã che Apple ID, số thiết bị và token. Kiểm tra lần lượt: nhận USB/Trust → Developer Mode → hạn mức App ID → cả hai extension còn trong IPA → backend/contract. Build IPA thành công, ký thành công, cài thành công và thử trên iPhone là bốn mốc riêng; tài liệu này không xác nhận các mốc chưa được thực hiện.
