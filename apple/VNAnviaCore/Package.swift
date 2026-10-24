// swift-tools-version: 5.9
import PackageDescription
let package = Package(name:"VNAnviaCore", platforms:[.iOS(.v17),.macOS(.v13)],
 products:[.library(name:"VNAnviaCore",targets:["VNAnviaCore"])],
 targets:[.target(name:"VNAnviaCore",resources:[.process("Resources")]),.testTarget(name:"VNAnviaCoreTests",dependencies:["VNAnviaCore"])])

