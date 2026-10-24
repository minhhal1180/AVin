# Web và OCR — thông báo thành phần bên thứ ba
Tesseract.js7.0.0 và tesseract.js-core được dùng cho OCR local. Worker/WASM và vie/eng từ tessdata_fast4.1.0 được phân phối cùng web/extension; SHA256 và URL nguồn nằm trong ocr/model-manifest.json, bản LICENSE đặt cạnh assets. Không tải model/runtime từ CDN khi chạy OCR.
Nguồn chính thức: [Tesseract.js](https://github.com/naptha/tesseract.js), [tesseract.js-core](https://github.com/naptha/tesseract.js-core), [tessdata_fast4.1.0](https://github.com/tesseract-ocr/tessdata_fast/tree/4.1.0).
React/ReactDOM và tr46 dùng MIT; Ajv dùng MIT. Phiên bản chính xác theo package-lock.json; inventory web được sinh từ package đã resolve, không suy quyền model từ license wrapper.
Android: MLKit Latin bundled16.0.1 và phụ thuộc Google dùng điều khoản SDK tương ứng; ảnh nhận dạng cục bộ, telemetry vận hành SDK theo chính sách Google. [Điều khoản MLKit](https://developers.google.com/ml-kit/terms), [data disclosure](https://developers.google.com/ml-kit/vision/text-recognition/android).
Apple Vision/SwiftUI/SafariServices là framework hệ điều hành theo điều khoản Apple SDK, không tái phân phối framework/weights Apple trong source.
docs/dependency-inventory.json và THIRD_PARTY_NOTICES.txt chứa inventory Android/Python. Mục metadata chưa có license trong POM cần review riêng trước internal-ready; không coi inventory là xác nhận pháp lý.

