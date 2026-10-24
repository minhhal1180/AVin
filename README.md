# VNAnvia — iOS build kit 0.3.0

Mã nguồn iOS17+ cho VNAnvia: app SwiftUI, Action Extension từ menu Chia sẻ, Safari Web Extension, Swift core/tests và tài nguyên OCR Safari đóng gói cục bộ.

**Trạng thái:** đã kiểm tra đóng gói trên Windows; chưa compile/ký bằng Xcode, chạy cloud build hoặc thử iPhone. Không có IPA đã ký. Backend VPS mới chưa deploy và cấu hình Gemini Free Tier vẫn chỉ cho dữ liệu mô phỏng server phê duyệt. Khóa provider và credential ký không nằm trong repository.

## Build online

- **Codemagic Personal:** kết nối repository này, chọn nhánh `main`, chạy workflow `ios-simulator` từ `codemagic.yaml`.
- **GitHub Actions:** mở **Actions → iOS simulator build (unsigned) → Run workflow**.

Hai workflow chỉ chạy thủ công. Script chạy Swift tests, sinh Xcode project bằng XcodeGen, build app cùng hai extension và chạy native simulator tests. Chỉ sau khi các bước đạt mới xuất `VNAnvia-simulator.app.zip`, build-info, checksum và logs. Không yêu cầu Apple signing credential hoặc khóa Gemini/Groq cho workflow unsigned này.

**Simulator app không cài lên iPhone thật.** Cài trên thiết bị cần ký app và cả hai extension; hướng dẫn Personal Team trên Mac hoặc quy trình IPA cloud nằm trong các tài liệu bên dưới.

## Tài liệu

- [Hướng dẫn build và cài iPhone](README_IOS.md).
- [So sánh Codemagic, GitHub Actions, Bitrise và Xcode Cloud](docs/engineering/IOS_ONLINE_BUILD_SERVICES.md).
- [Apple targets, signing và kiểm thử](apple/README.md).
- [Manifest hash của gói gốc](IOS-KIT-MANIFEST.json).

Giữ `apple/` và `dist/safari-extension/` cạnh nhau; tài nguyên Safari đã dựng sẵn nên không cần chạy npm trong kit này. Chạy `python3 apple/ci/verify-kit.py` để kiểm hash/layout; kiểm tra đó không chứng minh build native thành công. `README.md` này bổ sung cho GitHub, nằm ngoài manifest của ZIP gốc.

Gói gốc: `VNAnvia-0.3.0-ios-build-kit.zip`, SHA256 `752f24e912c9d8c534dfe42ab540f3c9cbb68479f0df7fbdf2f95f0a2f1e132a`. Không bật billing, ký, TestFlight hoặc tự phát hành trong cấu hình đi kèm.
