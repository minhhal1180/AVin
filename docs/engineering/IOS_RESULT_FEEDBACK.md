# Phản hồi và kết quả iPhone — 24/10/2026

Người dùng xác nhận kết nối thành công với VPS 0.3.0, sau đó thử văn bản khác mẫu đã duyệt và không thấy kết quả. Server đang giữ `real_content_enabled=false`: văn bản ngoài allowlist bị từ chối bằng HTTP403/FAILED/CONSENT_REQUIRED trước khi gọi provider. Đây là cấu hình thử nghiệm của VNAnvia, không phải tuyên bố mọi Free Tier đều cấm mọi văn bản tự nhập.

Transport iOS cũ bỏ body của mọi HTTP khác200 nên che mất lý do chặn. Kết quả thành công trước đây nằm dưới editor, cần cuộn để thấy. Bản sửa build4 giữ phản hồi FAILED hợp lệ với status/error, UUID và phiên bản khớp; không coi lỗi là đánh giá an toàn hay lừa đảo.

Luồng mới: kết nối → thẻ Chế độ thử nghiệm → Dùng mẫu OTP → nhập/review → consent từng lượt → xử lý → màn hình kết quả hoặc lý do chưa phân tích. Mẫu là DEV-T01-P nguyên văn, chỉ nạp sau thao tác người dùng, không tự gửi. Thay draft đang có phải xác nhận. Kết quả có nút quay lại của NavigationStack; draft giữ trong RAM. Edit/hủy/đổi nguồn/kết nối loại kết quả cũ. Bàn phím có nút Xong, hỗ trợ kéo đóng, đóng khi bấm kiểm tra và khi mở kết quả.

Giữ kiểu chữ hệ thống, SF Symbols, màu semantic và hit target44pt trở lên; lỗi có chữ và icon. Không thêm lịch sử, dịch vụ, SDK hay credential client. URL lexical vẫn cục bộ; website nâng cao chưa có worker VPS. Không thay backend, allowlist, quota hoặc privacy gate trong bản sửa này.

Kiểm chứng: core test kiểm HTTP/error/status/body, strict contract; native simulator test kiểm FAILED không assessment, kết quả mở màn hình, callback cũ bị bỏ, consent trước gửi, mẫu không tự gửi và URL không gọi cloud. Python kiểm mẫu đúng allowlist và đóng gói/validator IPA. Mac CI mới và artifact hash được ghi tại `qa/0.3.0/ios-result-feedback/`; không dùng build3 để chứng minh build4.

Sau khi Mac CI đạt, cài IPA mới bằng iloader đã đăng nhập. Cần thử trên iPhone thật: mẫu OTP → consent → màn hình HIGH/evidence, văn bản khác → lý do chỉ mẫu duyệt, quay lại/sửa, hủy và từ chối, bàn phím/chữ lớn/VoiceOver. Simulator/model tests không thay các phép thử thiết bị này.

Kiểm tra artifact đầu tiên phát hiện XcodeGen dùng CFBundleVersion1/CFBundleShortVersionString1.0 mặc định, dù build settings đã đặt4/0.3.0. Artifact đó bị giữ lại. Info.plist của app/Action/Safari nay lấy trực tiếp macro build settings; validator IPA đối chiếu phiên bản/build với project.yml và giữa ba bundle. Build lại tạo evidence/hash mới, không sửa IPA cũ hoặc dùng kết quả CI cũ để chứng nhận metadata mới.
