# Build VNAnvia iOS trực tuyến

Ngày rà soát tài liệu chính thức: **24/10/2026**. Hạn mức và image máy build có thể thay đổi; kiểm tra dashboard trước khi chạy. Đây là hướng dẫn cho mã Swift/SwiftUI, Action Extension và Safari Web Extension của VNAnvia. Chưa có bằng chứng build Xcode hoặc chạy trên iPhone cho gói này.

Đề xuất bắt đầu bằng **Codemagic Personal**, chạy workflow simulator có sẵn. GitHub Actions là lựa chọn tương đương nếu đang quản lý mã ở GitHub. Gói chứa cấu hình CI; chưa tạo tài khoản dịch vụ, kết nối Git, tải mã/credential lên cloud hoặc kích hoạt billing.

## Dịch vụ phù hợp

| Dịch vụ | Phần miễn phí và điều kiện | Áp dụng cho VNAnvia |
|---|---|---|
| **Codemagic Personal** | 500 phút macOS M2/tháng, một build song song; dành tài khoản cá nhân, không áp dụng tài khoản Teams. | Native iOS với `codemagic.yaml`; phù hợp sinh project bằng XcodeGen trong lượt build. [Hạn mức chính thức](https://docs.codemagic.io/billing/pricing/), [hướng dẫn native iOS](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/). |
| **GitHub Actions** | Standard runner miễn phí cho repo public. GitHub Free cá nhân và tổ chức có 2.000 plan minutes/tháng và 500 MB artifact storage cho private; đây không phải cam kết 2.000 phút Mac thực tế. | Chạy shell/XcodeGen/xcodebuild trong repo GitHub. OS và runner có cách tính chi phí khác; kiểm tra mức dùng trong Billing. [Billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions). |
| **Bitrise Hobby** | 300 credits/tháng, một private app, một người; credits không phải phút. Thời lượng phụ thuộc máy được chọn. | Hỗ trợ native iOS, GitHub/GitLab/Bitbucket hoặc URL Git khác; phải cấu hình thủ công nếu scanner chưa nhận project XcodeGen. [Pricing](https://bitrise.io/pricing), [kết nối project](https://docs.bitrise.io/en/bitrise-ci/getting-started/adding-a-new-project). |
| **Apple Xcode Cloud** | 25 compute hours/tháng đi kèm Apple Developer Program có phí; không phải quyền lợi Personal Team miễn phí. | Cần thiết lập ban đầu trong Xcode 15+ và App Store Connect. GitHub/GitLab/Bitbucket được hỗ trợ. Apple yêu cầu project/workspace hiện diện ổn định, cảnh báo project sinh động có thể làm cấu hình/build thất bại. [Hạn mức](https://developer.apple.com/xcode-cloud/get-started/), [yêu cầu project](https://developer.apple.com/documentation/xcode/Setting-up-your-project-to-use-Xcode-Cloud). |

Với Xcode Cloud, cần sinh và commit `.xcodeproj`, cấu hình trên Mac rồi kiểm tra workflow; không dùng nguyên gói chỉ có `project.yml` để cam kết build thành công. Codemagic và GitHub Actions cho phép chạy bước sinh project trước `xcodebuild`, nên thuận tiện hơn với cấu trúc hiện tại.

## Bắt đầu bằng Codemagic

Các đường dẫn dưới đây tính từ **root gói iOS sau khi giải nén**, nơi chứa `README_IOS.md`, `codemagic.yaml`, `.github/` và `apple/`. Không thêm một cấp thư mục bọc lên root Git; Codemagic tìm `codemagic.yaml` tại root repository. [Cấu trúc native iOS](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/).

1. Đọc `README_IOS.md`. Đưa nội dung gói đã giải nén vào một Git repository do bạn quản lý; có thể để private.
2. Đăng ký/đăng nhập Codemagic bằng **Personal account**. Chọn Add application, kết nối repo GitHub/GitLab/Bitbucket và chọn loại native iOS. Chỉ cấp quyền repo cần build. Private GitHub repo yêu cầu chủ repo cài Codemagic GitHub App. [Kết nối Git](https://docs.codemagic.io/getting-started/adding-apps/).
3. Chọn nhánh chứa `codemagic.yaml`, kiểm tra cấu hình rồi chạy workflow simulator bằng tay. Không cần nhập khóa Groq/Gemini hoặc Apple signing credential cho workflow unsigned này.
4. Sau khi build thành công, tải artifact, log và báo cáo mà workflow tạo. Chỉ đánh dấu build thành công khi log Xcode thực tế xác nhận; một file YAML hợp lệ chưa chứng minh compile thành công.

Cấu hình đã chọn `instance_type: mac_mini_m2` và `environment.xcode: latest`; cả hai được tài liệu YAML hỗ trợ. Không khai báo sự kiện `triggering` nghĩa là chạy thủ công. Artifact patterns có thể tương đối với clone root, dùng glob hoặc đường dẫn tuyệt đối. [YAML chính thức](https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/).

`latest` có thể đổi Xcode theo thời gian. Sau lượt thành công đầu tiên, ghi phiên bản Xcode/SDK/runner trong bằng chứng và pin phiên bản phù hợp trước khi nghiệm thu.

## Chạy bằng GitHub Actions

Dùng workflow trong `.github/workflows/` và script `apple/ci/build-ios.sh` của gói; đọc tên workflow và các bước cụ thể trong `README_IOS.md`. Đưa gói lên repo GitHub, chọn **Actions → workflow iOS → Run workflow**. Workflow được chuẩn bị cho thao tác thủ công; việc giải nén file ZIP không tự chạy cloud build.

`macos-15` hiện là standard runner Apple silicon M1, 3 CPU, 7 GB RAM, có cho cả repo public và private; `macos-15-intel` là nhãn khác. Simulator đích được chọn từ runtime thực tế trên máy, tránh phụ thuộc tên iPhone cố định. [Danh sách runner chính thức](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

Repo private dùng quota chung của chủ repo. Larger runners luôn tính phí riêng và không dùng free included minutes; workflow này dùng standard runner. [Billing GitHub](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [giá runner](https://docs.github.com/en/billing/reference/actions-runner-pricing).

## Simulator và iPhone thật

| Đầu ra | Có thể làm gì | Điều kiện |
|---|---|---|
| **Unsigned simulator `.app`/`.app.zip`** | Build và chạy với iOS Simulator trên Mac hoặc môi trường simulator cloud phù hợp. | Không cần Apple signing credential; **không cài lên iPhone thật**. [Codemagic simulator](https://docs.codemagic.io/yaml-code-signing/ios-simulator-builds/), [Bitrise simulator](https://docs.bitrise.io/en/bitrise-ci/deploying/ios-deployment/deploying-an-ios-app-for-simulators). |
| **Device build / signed `.ipa`** | Cài lên thiết bị theo phương thức provisioning đã chọn; TestFlight/App Store là quy trình phân phối riêng. | Cần certificate và profile hợp lệ. App chính và từng extension cần profile tương ứng; không chỉ ký container app. Quy trình ký cloud chính thức của Codemagic yêu cầu Apple Developer Program. [Ký iOS và extension profiles](https://docs.codemagic.io/yaml-code-signing/signing-ios/). |

Gói hiện chuẩn bị đường build unsigned để xác minh sớm. Để xuất IPA có chữ ký, phải cấu hình Team, bundle IDs, certificate và profiles riêng bằng kho secrets của CI; không đưa `.p12`, `.p8`, `.mobileprovision` hoặc mật khẩu vào Git. GitHub có [quy trình nhập signing certificate/profile bằng Secrets](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications). Không đổi đuôi `.app.zip` thành `.ipa` rồi coi là app đã ký.

Phương án thử iPhone miễn phí vẫn là mượn **Mac có Xcode**, đăng nhập Apple Account/Personal Team, chọn Team cho app và hai extension rồi Run trên iPhone đã pair. Apple quy định provisioning profile Personal Team hết hạn sau **7 ngày**, cần rebuild/reinstall; giới hạn ba app/thiết bị cùng các giới hạn App ID và thiết bị. Không coi Personal Team là phương án ký cloud/TestFlight đã được kiểm chứng cho dự án. [Apple: Personal Team và giới hạn](https://developer.apple.com/help/account/basics/about-your-developer-account).

Sau khi có build, vẫn phải thử Action Extension, Safari extension, Vision OCR tiếng Việt, Keychain, hủy/timeout, VoiceOver và consent trên iPhone thật. Simulator hoặc lượt build cloud không thay cho bằng chứng đó. Backend đích phải chạy đúng contract/engine/privacy; khóa provider ở server và không nằm trong gói iOS. Xem thêm [Apple build và kiểm thử](../../apple/README.md).
