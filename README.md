# VNAnvia — iOS build kit 0.3.0

Mã nguồn iOS17+ cho VNAnvia: app SwiftUI, Action Extension từ menu Chia sẻ, Safari Web Extension, Swift core/tests và tài nguyên OCR Safari đóng gói cục bộ.

**Trạng thái đã xác minh:** [build và test simulator thành công trên GitHub Actions](https://github.com/minhhal1180/AVin/actions/runs/40074879045) cho commit `66679d7`: Xcode16.4 trên macOS15.7.9 ARM64, 15 test Swift core và 4 native simulator tests đạt. Đã kiểm app chứa cả Action và Safari extension. Chưa ký IPA hoặc thử iPhone thật; chưa xác minh lại trên Xcode26.6 của Codemagic. Backend VPS mới chưa deploy và cấu hình Gemini Free Tier vẫn chỉ cho dữ liệu mô phỏng server phê duyệt. Khóa provider và credential ký không nằm trong repository.

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

`README_IOS.md` và manifest lưu trạng thái tại thời điểm đóng gói trước lượt CI nêu trên. Kết quả mới được dẫn ở đầu README này; một build simulator thành công không chứng minh ký/cài iPhone hoặc backend production đã sẵn sàng.
