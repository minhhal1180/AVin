# VNAnvia 0.3.0 — gói build iOS

Gói này chứa app SwiftUI iOS17+, Action Extension, Safari Web Extension, Swift core/tests, catalog/contract, icon và toàn bộ tài nguyên OCR Safari. Có sẵn cấu hình Codemagic và GitHub Actions để build trên Mac cloud. **Chưa có lượt compile/ký Xcode hoặc thử iPhone cho gói này; chưa có IPA.**

Khóa Groq/Gemini, backend, credential ký và provisioning profile không nằm trong gói. Backend VPS mới chưa được deploy; build ứng dụng thành công không chứng minh phân tích cloud đã hoạt động. Cấu hình Gemini Free Tier hiện chỉ chấp nhận dữ liệu mô phỏng server phê duyệt. Engine `hybrid-gemini-groq-1.0`, privacy `2026-10-24.1`, consent website `website-2026-10-24.1` cần khớp backend.

## Cấu trúc sau giải nén

```text
README_IOS.md                    Hướng dẫn này
IOS-KIT-MANIFEST.json             Hash từng file và trạng thái chưa build native
codemagic.yaml                   Workflow ios-simulator, chạy thủ công
.github/workflows/ios-unsigned.yml
.gitignore / .gitattributes       Giữ tài nguyên và byte đã kiểm khi đưa lên Git
apple/                           Swift source, tests, project.yml, hướng dẫn Apple
apple/ci/                        Script build + kiểm hash/layout không cần mạng
dist/safari-extension/           JS, icons, worker/WASM, vie/eng và license
docs/engineering/IOS_ONLINE_BUILD_SERVICES.md
provenance/                      npm lock và metadata để truy nguồn bản JS dựng sẵn
licenses/npm/                    License từ các package runtime đã resolve
```

Giữ `apple/` và `dist/` cạnh nhau. Safari resources đã dựng sẵn nên **không chạy npm** trong gói rút gọn này. Source TypeScript/backend đầy đủ vẫn ở project gốc; lockfile trong `provenance/` để đối chiếu, không phải môi trường npm độc lập của kit.

## Cách đề xuất: Codemagic Personal

1. Giải nén ZIP; tạo một repository Git do bạn quản lý, ưu tiên private. Đưa **nội dung bên trong** gói vào root repo: tại root phải thấy `codemagic.yaml` và `apple/`. Giữ cả `.github`, `.gitignore`, `.gitattributes` và **dist/**. Không thêm secrets.
2. Kết nối repository với Codemagic Personal, chọn native iOS và cấu hình YAML ở nhánh đã đưa lên.
3. Chọn workflow **ios-simulator**, bấm Start new build. Workflow unsigned không cần tài khoản Apple hay khóa API provider.
4. Sau khi chạy thật, tải `VNAnvia-simulator.app.zip`, `build-info.json`, checksum và logs. `build-info.json` chỉ ghi trạng thái passed sau khi Swift core tests, Xcode build, native simulator tests và hai extension embedded đều đạt.

Workflow cài XcodeGen nếu thiếu; sinh `.xcodeproj` từ `apple/project.yml`, dùng Xcode đang có trên runner, chọn iPhone simulator iOS17+ thực tế. Đây là cấu hình đã chuẩn bị, chưa phải một build cloud đã chạy thành công. Chi tiết hạn mức, ký và các dịch vụ khác nằm trong `docs/engineering/IOS_ONLINE_BUILD_SERVICES.md`.

## GitHub Actions

Đưa nội dung kit lên GitHub, vào **Actions → iOS simulator build (unsigned) → Run workflow**. File `.github/workflows/ios-unsigned.yml` chỉ chạy thủ công, dùng standard runner `macos-15`, quyền đọc source và lưu artifact ba ngày. Không cấu hình signing, phát hành hoặc sự kiện push/PR. Sau khi job kết thúc, tải artifact **VNAnvia-iOS-simulator**; nếu lỗi, xem log Swift/Xcode trong artifact hoặc log job.

Các action đã pin commit: checkout `v7.0.1`, upload-artifact `v7.0.2`, đối chiếu release chính thức ngày24/10/2026. XcodeGen cài từ Homebrew và Xcode image có thể thay đổi; script ghi phiên bản, OS và kiến trúc thực tế vào build-info. Pin Xcode/toolchain phù hợp sau lượt build thành công đầu tiên. Simulator app mặc định theo kiến trúc runner, không hứa tương thích simulator Mac Intel.

## Build trên Mac có sẵn

Xcode đầy đủ và một runtime iPhone simulator iOS17+ phải được cài trước. Cài XcodeGen2.44+ qua Homebrew nếu chưa có. Tại root gói:

```bash
python3 apple/ci/verify-kit.py
bash apple/ci/build-ios.sh
```

Output nằm trong `build/ios-cloud/<timestamp>/`. Script không xóa thư mục hoặc nhập credential. Có thể đặt `VNANVIA_IOS_OUTPUT` để chọn thư mục đầu ra mới; tránh dùng lại thư mục đã có `native-tests.xcresult`. Không cần Python dependency ngoài thư viện chuẩn.

Preflight kiểm hash **không chứng minh compile thành công**. Nếu sửa source/config của kit, manifest gốc sẽ phát hiện thay đổi; tạo lại gói từ project đầy đủ bằng `.venv/Scripts/python.exe -m scripts.package_ios`, không tắt preflight để giữ trạng thái cũ.

## Cài trên iPhone thật

`VNAnvia-simulator.app.zip` chỉ dùng cho iOS Simulator; **không cài lên iPhone thật**. Không đổi tên ZIP thành IPA để cài.

- **Ưu tiên miễn phí:** mượn Mac có Xcode, chạy `(cd apple && xcodegen generate)`, mở `apple/VNAnvia.xcodeproj`; chọn Personal Team của bạn cho app và cả hai extension, kết nối/pair iPhone, chọn scheme VNAnvia rồi Run. Nếu bundle IDs không khả dụng, đổi đồng bộ và kiểm lại cấu hình Safari native messaging; xem `apple/README.md`. Personal Team cần rebuild/reinstall sau hạn provisioning7ngày theo [Apple](https://developer.apple.com/help/account/basics/about-your-developer-account).
- **IPA ký trên cloud:** cấu hình Apple Developer Program, Team, certificate và profile riêng cho app, Action và Safari extension trong kho secrets CI. Cấu hình unsigned đi kèm không xuất signed IPA hoặc tự phân phối TestFlight. [Codemagic: ký iOS và profiles của extension](https://docs.codemagic.io/yaml-code-signing/signing-ios/).

Sau khi có build thật vẫn cần kiểm Safari/Action từ ứng dụng nguồn, Vision OCR tiếng Việt, Keychain, consent/cancel/stale, bàn phím và VoiceOver trên iPhone. Xem `apple/README.md`. Kiểm backend phiên bản tương thích trước thử cloud; không đưa khóa Gemini/Groq vào Xcode hoặc CI.
