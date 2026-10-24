# VNAnvia — iOS build kit 0.3.0

**Cập nhật build4 ngày24/10:** sửa lỗi mất lý do server403, thêm thẻ chỉ nhận mẫu đã duyệt và mẫu OTP không tự gửi, đưa kết quả/lỗi sang màn hình riêng, đóng bàn phím khi kiểm tra. Có7 core transport tests mới và7 native model tests mới. Mac CI đang được chạy lại cho đúng commit; chưa coi bằng chứng build3 bên dưới là kiểm chứng build4. Xem [chi tiết](docs/engineering/IOS_RESULT_FEEDBACK.md).

VPS0.3.0 đã triển khai và người dùng báo iPhone kết nối thành công. Dữ liệu thật vẫn đóng; văn bản khác mẫu server duyệt bị từ chối trước AI. Website nâng cao chưa có capture worker VPS. Bản iPhone đã cài trước đó là build3, cần IPA build4 sau khi CI đạt.

Gói nguồn build4 SHA256 `5a06a527ef4b9dd7bbdabe30d5d6d7b1f98153d26e6d8b9bb5125de9c1320e74`; manifest kèm125file, không chứa provider/signing secret. Các mô tả CI/IPA build3 dưới đây là lịch sử, có hash riêng.

[Simulator kiểm thử phần Swift đã đạt](https://github.com/minhhal1180/AVin/actions/runs/40082791511) tại `498631b`:22core+11native tests. Kiểm IPA sau lượt đó phát hiện Info.plist vẫn ghi1.0/1 mặc định. Project nay gắn macro phiên bản vào app và hai extension; validator đối chiếu project.yml, đóng gói đang build lại. Không dùng IPA sai metadata làm bản bàn giao cuối.

Mã nguồn iOS17+ cho VNAnvia: app SwiftUI, Action Extension từ menu Chia sẻ, Safari Web Extension, Swift core/tests và tài nguyên OCR Safari đóng gói cục bộ.

**Trạng thái đã xác minh:** [build và test simulator thành công trên GitHub Actions](https://github.com/minhhal1180/AVin/actions/runs/40074879045) cho commit `66679d7`: Xcode16.4 trên macOS15.7.9 ARM64, 15 test Swift core và 4 native simulator tests đạt. Đã kiểm app chứa cả Action và Safari extension. Chưa ký IPA hoặc thử iPhone thật; chưa xác minh lại trên Xcode26.6 của Codemagic. Backend VPS mới chưa deploy và cấu hình Gemini Free Tier vẫn chỉ cho dữ liệu mô phỏng server phê duyệt. Khóa provider và credential ký không nằm trong repository.

## Cài iPhone bằng Apple ID miễn phí và Windows

Trên Codemagic, làm mới nhánh `main`, bấm **Start new build** và chọn **ios-device-unsigned**. Tải `VNAnvia-device-unsigned.ipa` rồi ký/cài bằng Sideloadly trên Windows. [Hướng dẫn từng bước](docs/engineering/IOS_FREE_INSTALL.md).

Workflow mới build Release/iphoneos/arm64 bằng Xcode16.4, giữ hai extension, kiểm Info.plist và Mach-O trước khi xuất IPA. Không nhập Apple ID hoặc signing credential vào CI. IPA cần ký local trước khi cài và refresh trong vòng bảy ngày với tài khoản miễn phí. Safari Web Extension có yêu cầu chính thức Developer Program khi thử trên thiết bị; chưa cam kết hoạt động qua Sideloadly miễn phí. [Apple](https://developer.apple.com/documentation/safariservices/running-your-safari-web-extension).

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

Gói nguồn cập nhật: `VNAnvia-0.3.0-ios-build-kit.zip`, SHA256 `b594afe625909ea23526000ae17c2827d4dcbc5eb037fcc48b2677d674d7dae7`. Không bật billing, ký, TestFlight hoặc tự phát hành trong cấu hình đi kèm.

`README_IOS.md` và manifest lưu trạng thái tại thời điểm đóng gói trước lượt CI nêu trên. Kết quả mới được dẫn ở đầu README này; một build simulator thành công không chứng minh ký/cài iPhone hoặc backend production đã sẵn sàng.
