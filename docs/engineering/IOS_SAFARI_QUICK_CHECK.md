# Kiểm tra nhanh trong Safari — build6

Build6 thêm hướng dẫn kích hoạt ngay lần mở app đầu tiên và nút **Cho phép trên website này** trong popup Safari. Chỉ lưu cờ đã xem hướng dẫn; cờ không đại diện quyền Safari. Từ chối quyền không gửi văn bản, không bật nền hoặc lặp lời nhắc. Có thể mở lại hướng dẫn trong app.

Trên iPhone18.5/Xcode16.4 hiện tại không có API công khai mở trực tiếp màn hình bật extension. `SFSafariSettings.openExtensionsSettings(forIdentifiers:)` cần iOS26.2; không dùng private URL hoặc giả trạng thái đã bật. Người dùng mở app một lần, bật VNAnvia trong Safari, rồi nhấn nút cấp quyền theo website. HTTPS hướng dẫn Apple mở trình duyệt mặc định; không hứa tự mở Safari. [Apple API](https://developer.apple.com/documentation/safariservices/sfsafarisettings/openextensionssettings(foridentifiers:completionhandler:)), [quyền Safari](https://developer.apple.com/documentation/safariservices/managing-safari-web-extension-permissions).

Origin hiện tại được chuẩn bị trước khi chạm nút; `permissions.request` gọi ngay trong click tin cậy, chỉ yêu cầu website đó. Chấp thuận xong kiểm lại tab/origin rồi mới bật nút chọn chữ. Thay website/hủy/không hỗ trợ đều không gọi AI. Host permission là tùy chọn, không yêu cầu mọi website một lượt. Hạn chế menu/trang/Share và consent bên dưới vẫn áp dụng. Bằng chứng lượt mới: `qa/0.3.0/activation/`.

Android build5 có onboarding tương ứng, vùng chữ mô phỏng chọn được và nút Hướng dẫn. Không có quyền bật PROCESS_TEXT: action đăng ký khi cài, app nguồn quyết định menu; dùng Chia sẻ/dán khi nguồn không hỗ trợ. Không thêm Accessibility/overlay/SMS. Share đầu tiên được ưu tiên review thay vì bị guide che. Chrome Android không cài extension PC; không coi hướng dẫn là hộp thoại quyền của hệ điều hành. [Android PROCESS_TEXT](https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT), [Google](https://support.google.com/chrome_webstore/answer/1698338).

## Lịch sử build5

Người dùng24/10/2026 xác nhận có “VNAnvia Safari” trong Cài đặt nhưng chưa bật. Đây là nguyên nhân trực tiếp tiện ích chưa chạy; ảnh menu chọn chữ riêng lẻ không xác định được trạng thái quyền. Safari iOS không hỗ trợ `contextMenus` như Chromium: [Apple compatibility](https://developer.apple.com/documentation/safariservices/assessing-your-safari-web-extension-s-browser-compatibility).

## Dùng ngay với bản đang cài

1. Cài đặt → Ứng dụng → Safari → Phần mở rộng → VNAnvia Safari → Cho phép.
2. Mở website trong Safari, mở menu trang → VNAnvia, cấp quyền cho website. Tải lại nếu cần.
3. Với build4, chọn VNAnvia trong menu Safari để bật nút trên trang trước khi tô đen. Chạm “Kiểm tra đoạn này”, xem lại và xác nhận gửi nếu cần phân tích TEXT.

Tên menu có thể khác theo ngôn ngữ/iOS. [Hướng dẫn bật tiện ích của Apple](https://support.apple.com/guide/iphone/iphab0432bf6/ios).

## Luồng build5

Sau khi được bật và cấp quyền website, content script chỉ lắng nghe thao tác chọn chữ trên trang đó. Tô đen → nút cạnh đoạn chọn → tab VNAnvia để xem/sửa và consent. Menu tiện ích cũng có “Hiện nút khi tô đen”, “Kiểm tra phần đã chọn” và “Mở bảng kiểm tra”. App chính có hướng dẫn ba bước dạng thẻ.

- Không đọc toàn trang, gửi nền, thêm mục vào menu hệ thống hoặc tự gọi AI khi tô đen.
- Không đọc password; một đoạn tối đa4.000 codepoints, giữ nguyên Unicode và khoảng trắng khi chuyển sang review.
- Nội dung chỉ ở RAM; URL mở tab chứa UUID, không chứa đoạn chọn. Credential/API nằm trong native handler; popup và content script không nhận bearer.
- Chỉ trang http/https được cấp quyền; không cam kết trang Safari nội bộ, PDF, chế độ Đọc hoặc iframe khác nguồn. Có thể dùng Chia sẻ → VNAnvia hoặc dán nếu nguồn không cung cấp selection.
- Nhấn bằng ngón tay giữ snapshot; đổi trang/hủy selection loại dữ liệu cũ. Nút được giới hạn theo visual viewport.

Build5 phải giữ cả ActionExtension và SafariWebExtension khi ký/cài bằng iloader. Bản IPA ban đầu có hai extension không chứng minh bản đã ký giữ nguyên chúng hoặc quyền được bật. Không đưa chứng chỉ/Apple password vào source. Giữ các gate VPS: real-content=false, website=false; TEXT thật chưa được server cho phép, kể cả khi nút chọn chữ hoạt động.

## Kiểm chứng

Unit/mock kiểm extractor, password, Unicode, popup sender và ranh giới native. Browser automation kiểm shared content script với touch emulation trên Chromium, **không phải Safari/iPhone thật**. Mac CI kiểm compile/build các target và native tests. Kiểm trên iPhone vẫn cần: bật quyền theo site, kéo tay chọn chữ, chạm nút cạnh đoạn, từ chối/đồng ý consent, lấy kết quả mẫu đã duyệt, điều hướng/back/zoom, VoiceOver và quên phiên.

Bằng chứng mới tại `qa/0.3.0/safari-quick/`; không dùng build4 hoặc Android QA để chứng nhận build5.
