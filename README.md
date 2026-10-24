# VNAnvia — iOS build kit 0.3.0

**Build6 — hướng dẫn kích hoạt lần đầu:** app hiện các bước bật VNAnvia trong Safari ở lần mở đầu, có “Để sau” và mở lại hướng dẫn. Popup có nút “Cho phép trên website này”, gọi yêu cầu quyền trong lần chạm và chỉ xin website hiện tại. Từ chối không gửi văn bản. iOS18.5 vẫn cần người dùng bật tiện ích trong Safari; quyền website được xin sau thao tác chạm. Xem [hướng dẫn](docs/engineering/IOS_SAFARI_QUICK_CHECK.md).

**Mac CI build6 đã đạt:** [IPA iPhone](https://github.com/minhhal1180/AVin/actions/runs/40094291909) và [simulator](https://github.com/minhhal1180/AVin/actions/runs/40094291546) tại commit `4e444918cb41897e9eb7e699964682eea71f64d6`,22core+13native tests không lỗi. IPA đủ3bundle0.3.0/build6, SHA256 `0036afa6b0950b5ee03f28ff0c1d0294334a3f7520647d1ad86c976920fa2f7c`. Gói chưa ký; cần ký/cài bằng iloader, giữ2extension và bật Safari/cấp quyền website. Chưa xác minh build6 trên iPhone thật.

Đã kiểm177TypeScript tests và66Python packaging tests. Chỉ lưu cờ đã xem hướng dẫn, không coi đó là trạng thái quyền Safari. VPS giữ real-content=false/website=false, không thay consent/quota/provider.

## Mốc build5 (lịch sử)

**Build5 — kiểm tra nhanh khi tô đen trong Safari:** bật VNAnvia Safari và cho phép website, tô đen rồi chạm nút “Kiểm tra đoạn này”. Có popup kích hoạt và hướng dẫn ba bước trong app. Xem [hướng dẫn](docs/engineering/IOS_SAFARI_QUICK_CHECK.md). Safari iOS không có mục contextMenus như Chrome. Source này cần Mac CI mới; bằng chứng build4 bên dưới chưa chứng nhận build5 hoặc thao tác trên iPhone.

Đã kiểm139TypeScript tests,66kiểm đóng gói Python và shared content script bằng Chromium có touch emulation. TEXT chờ consent; không tự gửi AI khi chọn chữ. VPS vẫn chỉ cho mẫu mô phỏng được duyệt, website worker chưa triển khai. Không có khóa provider trong client.

**Mac CI build5 đã đạt:** [IPA iPhone](https://github.com/minhhal1180/AVin/actions/runs/40093019866) và [simulator](https://github.com/minhhal1180/AVin/actions/runs/40093019843) tại commit `0d2a0355096d26af6a09b86183d4a950226455e8`,22core+11native tests không lỗi. IPA đủ3bundle0.3.0/build5, SHA256 `5fac113176ef9cf5c2fd56a25aa25b7514ef325b6d6418c50b65d335d6381a74`. Gói chưa ký; cần ký/cài bằng iloader, giữ2extension và bật Safari/cấp quyền site. Chưa xác minh thao tác Safari/iPhone thật. Việc mở bảng kiểm tra có thể xin phiên/khả năng tự động; đoạn chọn chỉ gửi AI sau consent.

## Lịch sử xác minh trước build5

**Cập nhật build4 ngày24/10:** sửa lỗi mất lý do server403, thêm thẻ chỉ nhận mẫu đã duyệt và mẫu OTP không tự gửi, đưa kết quả/lỗi sang màn hình riêng, đóng bàn phím khi kiểm tra. [Final Mac CI](https://github.com/minhhal1180/AVin/actions/runs/40083355803) đã build Release/iphoneos/arm64 thành công tại `57544b9`,22core tests đạt. IPA cuối đủ ba bundle0.3.0/build4, SHA256 `4886af668e087a7b3c398c997a48af05c847ab4a9c5f650cd6952f0ab94b52b0`; chưa ký/thử bản mới trên iPhone. Xem [chi tiết](docs/engineering/IOS_RESULT_FEEDBACK.md).

VPS0.3.0 đã triển khai và người dùng báo iPhone kết nối thành công. Dữ liệu thật vẫn đóng; văn bản khác mẫu server duyệt bị từ chối trước AI. Website nâng cao chưa có capture worker VPS. Bản iPhone đã cài trước đó là build3, cần IPA build4 sau khi CI đạt.

Gói nguồn build4 SHA256 `5a06a527ef4b9dd7bbdabe30d5d6d7b1f98153d26e6d8b9bb5125de9c1320e74`; manifest kèm125file, không chứa provider/signing secret. Các mô tả CI/IPA build3 dưới đây là lịch sử, có hash riêng.

[Simulator kiểm thử phần Swift đã đạt](https://github.com/minhhal1180/AVin/actions/runs/40082791511) tại `498631b`:22core+11native tests. Kiểm IPA sau lượt đó phát hiện Info.plist vẫn ghi1.0/1 mặc định. Project nay gắn macro phiên bản vào app và hai extension; validator đối chiếu project.yml. Final device CI đã xác nhận0.3.0/build4;23Swift source/test files trùng byte với simulator đã chạy. Không dùng IPA sai metadata làm bản bàn giao cuối.

Mã nguồn iOS17+ cho VNAnvia: app SwiftUI, Action Extension từ menu Chia sẻ, Safari Web Extension, Swift core/tests và tài nguyên OCR Safari đóng gói cục bộ.

**Trạng thái đã xác minh:** [build và test simulator thành công trên GitHub Actions](https://github.com/minhhal1180/AVin/actions/runs/40074879045) cho commit `66679d7`: Xcode16.4 trên macOS15.7.9 ARM64, 15 test Swift core và 4 native simulator tests đạt. Đã kiểm app chứa cả Action và Safari extension. Chưa ký IPA hoặc thử iPhone thật; chưa xác minh lại trên Xcode26.6 của Codemagic. Backend VPS mới chưa deploy và cấu hình Gemini Free Tier vẫn chỉ cho dữ liệu mô phỏng server phê duyệt. Khóa provider và credential ký không nằm trong repository.

## Cài iPhone bằng Apple ID miễn phí và Windows

Tải `VNAnvia-device-unsigned.ipa` từ artifact **VNAnvia-iPhone-unsigned** của [lượt build6 đã đạt](https://github.com/minhhal1180/AVin/actions/runs/40094291909). Kết nối iPhone với Windows, mở **iloader**, chọn thiết bị và IPA rồi ký/cài bằng Apple ID trên máy của bạn. Giữ cả Action Extension và Safari Web Extension khi ký. Người dùng đã cài thành công bằng iloader; Sideloadly trước đó gặp lỗi đăng nhập. Không nhập Apple ID hoặc mật khẩu vào chat, Git hay CI.

Nếu dùng Codemagic cho lượt build sau, làm mới nhánh `main`, bấm **Start new build** và chọn **ios-device-unsigned**. Tài liệu [cài miễn phí](docs/engineering/IOS_FREE_INSTALL.md) có thêm hướng dẫn và giới hạn ký.

Workflow mới build Release/iphoneos/arm64 bằng Xcode16.4, giữ hai extension, kiểm Info.plist và Mach-O trước khi xuất IPA. IPA cần ký local trước khi cài và refresh trong vòng bảy ngày với tài khoản miễn phí. Trên iOS18.5, mở Safari → menu trang → Quản lý phần mở rộng để bật VNAnvia Safari, rồi chạm “Cho phép trên website này” trong popup và tải lại trang. Safari Web Extension có yêu cầu chính thức Developer Program khi thử trên thiết bị; việc đã cài app qua iloader chưa chứng minh extension hoạt động. [Apple](https://developer.apple.com/documentation/safariservices/running-your-safari-web-extension).

GitHub có workflow tương đương **Actions → iPhone IPA build (unsigned) → Run workflow**, artifact **VNAnvia-iPhone-unsigned**. [Build device đã thành công](https://github.com/minhhal1180/AVin/actions/runs/40077591154) cho commit `d85eb3d`: Xcode16.4, Release/iphoneos/arm64, 15 core tests đạt. Đã tải IPA và đối chiếu hash, platform iOS17+ và đủ ba executable app/Action/Safari. IPA SHA256 `4b542536e78651b98fa35afa8311a100ec9e8336883b54ac1e716e223946814d`; chưa ký hoặc thử iPhone. Codemagic mới có cấu hình, chưa có lượt build workflow device tại đó trong phiên này.

## Kiểm thử simulator online

- **Codemagic Personal:** kết nối repository này, chọn nhánh `main`, chạy workflow `ios-simulator` từ `codemagic.yaml`.
- **GitHub Actions:** mở **Actions → iOS simulator build (unsigned) → Run workflow**.

Các workflow chỉ chạy thủ công. Script simulator chạy Swift tests, sinh Xcode project bằng XcodeGen, build app cùng hai extension và chạy native simulator tests. Chỉ sau khi các bước đạt mới xuất `VNAnvia-simulator.app.zip`, build-info, checksum và logs. Không yêu cầu Apple signing credential hoặc khóa Gemini/Groq cho workflow unsigned này.

**Simulator app không cài lên iPhone thật.** Cài trên thiết bị cần ký app và cả hai extension; hướng dẫn Personal Team trên Mac hoặc quy trình IPA cloud nằm trong các tài liệu bên dưới.

## Tài liệu

- [Hướng dẫn build và cài iPhone](README_IOS.md).
- [So sánh Codemagic, GitHub Actions, Bitrise và Xcode Cloud](docs/engineering/IOS_ONLINE_BUILD_SERVICES.md).
- [Apple targets, signing và kiểm thử](apple/README.md).
- [Manifest hash của gói gốc](IOS-KIT-MANIFEST.json).

Giữ `apple/` và `dist/safari-extension/` cạnh nhau; tài nguyên Safari đã dựng sẵn nên không cần chạy npm trong kit này. Chạy `python3 apple/ci/verify-kit.py` để kiểm hash/layout; kiểm tra đó không chứng minh build native thành công. `README.md` này bổ sung cho GitHub, nằm ngoài manifest của ZIP gốc.

Gói nguồn cập nhật: `VNAnvia-0.3.0-ios-build-kit.zip`, SHA256 `89623ef35c82300cc6823af88e48a6531c909e4082cbdf5e263ecd8600c5a200`. Không bật billing, ký, TestFlight hoặc tự phát hành trong cấu hình đi kèm.

`README_IOS.md` và manifest lưu trạng thái tại thời điểm đóng gói trước lượt CI nêu trên. Kết quả mới được dẫn ở đầu README này; một build simulator thành công không chứng minh ký/cài iPhone hoặc backend production đã sẵn sàng.
