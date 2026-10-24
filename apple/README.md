# Apple build và kiểm thử
Gói Apple rút gọn có build cloud cho simulator và IPA iPhone chưa ký: xem [hướng dẫn build kit](../docs/engineering/IOS_BUILD_KIT.md), [cài miễn phí bằng Sideloadly trên Windows](../docs/engineering/IOS_FREE_INSTALL.md) và [dịch vụ online](../docs/engineering/IOS_ONLINE_BUILD_SERVICES.md). Trong ZIP, hướng dẫn ở root có tên `README_IOS.md`; tài nguyên Safari đã đóng gói nên không cần chạy bước npm/sync dưới đây.

Mã iOS17+; [Mac CI simulator](https://github.com/minhhal1180/AVin/actions/runs/40074879045) đã build và chạy 15 core + 4 native tests trên Xcode16.4 cho source `66679d7`. Chưa có bằng chứng ký/cài hoặc chạy iPhone; workflow device mới có evidence riêng khi chạy.

1. Tại project root: npm ci; npm run assets:ocr; node scripts/build-safari.mjs.
2. Đồng bộ contract: .venv/Scripts/python.exe -m scripts.sync_apple_resources (trên Mac dùng python3).
3. Mac với Xcode, XcodeGen2.44+ (cài qua Homebrew nếu chưa có): cd apple; xcodegen generate; open VNAnvia.xcodeproj.
4. Chọn cùng Personal Team của bạn cho app và hai extension. Đổi đồng bộ prefix bundle ID nếu cần. Không đưa certificate/provisioning profile vào source.
5. Chạy swift test --package-path VNAnviaCore; build scheme VNAnvia; chọn iPhone đã trust/pair, bật Developer Mode nếu iOS yêu cầu, Run.
6. Safari Settings → Extensions → VNAnvia → bật và cấp quyền theo website. Trong app khác dùng Share → Actions → VNAnvia; nguồn có thể không cấp đủ nội dung.
7. App, Action Extension và Safari tự xin phiên từ backend; người dùng không nhập mã, khóa hoặc endpoint. Mặc định không lưu phiên; các target quản lý credential riêng, không có App Groups hoặc chia sẻ Keychain.
8. Personal Team miễn phí thường cần rebuild/reinstall sau hạn provisioning7ngày; mở Xcode chọn Team/device rồi Run lại. Không cần TestFlight làm mặc định.

Chạy TEST_PLAN_0.3 trên iPhone thật: Vision tiếng Việt (kiểm supportedRecognitionLanguages),20ảnh OCR, back/cancel/stale, native messaging, Keychain expiry/restart, VoiceOver/DynamicType/keyboard và30UIruns.
Nếu capability/contract không khớp, build lại backend+clients từ cùng source. Không thay cấu hình để bỏ strict-check.
Project generator là nguồn cấu trúc target; file Xcode sinh ra cần review trên Mac. Simulator build/test đã có evidence nêu trên; không suy ra device hoặc signing passed.

Scheme `VNAnvia` đã gắn `VNAnviaNativeTests`: trên Mac chạy `xcodebuild test -project apple/VNAnvia.xcodeproj -scheme VNAnvia -destination 'platform=iOS Simulator,name=<tên iPhone simulator đã cài>'`. Thay destination bằng thiết bị/simulator thực tế trên Mac. Các test dùng store bộ nhớ mô phỏng để kiểm opt-in/opt-out, restore, forget và giữ nguyên deadline; không thay bằng chứng Keychain thật trên iPhone. Cấu trúc test target theo [XcodeGen Project Spec](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#test-action).

Icon ứng dụng mới ở `VNAnviaApp/Assets.xcassets`; ảnh nhãn hiệu dùng chung ở `Shared/Assets.xcassets`. Safari bundle phải kèm thư mục `icons` như `project.yml`. Sau khi đồng bộ assets, cần generate/build lại project trên Mac trước khi thử cài.
Backend đích phải triển khai POST /session cùng contract 0.3; cấu hình Gemini, Groq và signing key chỉ nằm trên server. Khóa đã cấu hình ở máy Windows không tự xuất hiện trên VPS hoặc iPhone. Web/PWA local đang chạy trên Windows không thay bằng chứng native iPhone.
Nguồn: [Apple native messaging](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension), [tài khoản](https://developer.apple.com/help/account/basics/about-your-developer-account).

Rà soát source ngày 23/10/2026 đã bổ sung deadline đơn 15 giây cho toàn lượt nhận/đọc/OCR; hủy `Progress` và Vision khi hủy/đổi nguồn/đóng Action Extension; loại kết quả sau khi quên, đổi hoặc hết phiên. URL local không bị khóa khi kết nối cloud đang chờ. Đây là thay đổi source chưa có bằng chứng runtime Apple.

Trước khi nghiệm thu trên Mac/iPhone cần kiểm tra thêm:

- `swift test --package-path apple/VNAnviaCore` từ project root: conformance và `testNativeRequestBoundary` (UUID4, schema/privacy, giới hạn Unicode, trim).
- Action Extension từ Safari, Notes và Photos: nhận text/link/ảnh, nguồn không hỗ trợ, quá15giây; nút Hủy trong lúc chờ; callback sau khi đóng không mở màn hình mới.
- Picker: chọn ảnh rồi Hủy/đổi TEXT/URL trước khi OCR hoàn tất; không hiện chữ cũ, Vision/loader nhận cancel; tổng deadline không cộng thêm15giây sau khi tải ảnh xong.
- Kết thúc phiên hoặc kết nối lại lúc capabilities/analyze đang chờ; response cũ không phục hồi credential hoặc cập nhật kết quả. Kiểm phiên hết hạn ngay trong lượt analyze.
- Safari native messaging: operation/field lạ, UUID sai, URL ở request TEXT, schema/privacy sai phải bị từ chối trước HTTP. Content script vẫn không nhận bearer.

Cơ chế cancel dùng API của Apple: [NSItemProvider loadObject](https://developer.apple.com/documentation/foundation/nsitemprovider/loadobject(ofclass:completionhandler:)-6pysm), [loadFileRepresentation](https://developer.apple.com/documentation/foundation/nsitemprovider/loadfilerepresentation(fortypeidentifier:completionhandler:)), [VNRequest](https://developer.apple.com/documentation/vision/vnrequest). Cancel yêu cầu dừng công việc đang chạy; không tuyên bố có thể ngắt ImageIO tức thời giữa một lệnh decode.

