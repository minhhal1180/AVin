import Foundation

enum AnalysisFeedback {
 static let demoText="Tôi cần xác minh tài khoản. Hãy đọc mã OTP vừa nhận cho tôi qua điện thoại."
 static func message(_ code:String)->String {
  switch code {
  case "CONSENT_REQUIRED":return "Server hiện chỉ nhận mẫu mô phỏng đã duyệt. Văn bản này chưa được gửi tới AI. Chọn Dùng mẫu OTP để thử; bạn vẫn cần xác nhận trước khi gửi."
  case "RATE_LIMITED":return "Đã đạt giới hạn lượt phân tích. Hãy chờ rồi thử lại."
  case "UNAUTHORIZED":return "Phiên kết nối đã hết hạn hoặc không còn hợp lệ. Vào Dịch vụ để kết nối lại."
  case "ANALYSIS_TIMEOUT":return "Phân tích quá thời gian chờ. Nội dung vẫn còn; bạn có thể thử lại."
  case "AI_RESPONSE_INVALID", "INCOMPATIBLE_BACKEND":return "Phản hồi không đáp ứng hợp đồng của ứng dụng. Chưa có đánh giá; hãy thử lại sau."
  case "INVALID_INPUT", "UNSUPPORTED_URL":return "Nội dung không hợp lệ hoặc chưa được hỗ trợ. Quay lại để kiểm tra và sửa."
  default:return "Chưa hoàn tất phân tích. Hãy kiểm tra kết nối và thử lại. Nội dung vẫn còn trong phiên."
  }
 }
}
