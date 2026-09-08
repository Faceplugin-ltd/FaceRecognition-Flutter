// swift-tools-version: 5.9
// Flutter plugin package for face_recognition_sdk (CocoaPods + SwiftPM).
// Vendored native runtimes live in ios/Frameworks/*.xcframework (created by
// dart run tool/bootstrap.dart / example/ios pod install from Drive .frameworks).
//
// Local path checkouts named FaceRecognition-Flutter-App hit Flutter SPM
// identity bugs (flutter/flutter#186881). The example disables SPM and uses
// CocoaPods.

import PackageDescription

let package = Package(
  name: "face_recognition_sdk",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "face-recognition-sdk", targets: ["face_recognition_sdk"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .binaryTarget(
      name: "facerecognitionsdk",
      path: "../Frameworks/facerecognitionsdk.xcframework"
    ),
    .binaryTarget(
      name: "FaceRecognitionEngine",
      path: "../Frameworks/FaceRecognitionEngine.xcframework"
    ),
    .binaryTarget(
      name: "onnxruntime",
      path: "../Frameworks/onnxruntime.xcframework"
    ),
    .target(
      name: "face_recognition_sdk",
      dependencies: [
        "facerecognitionsdk",
        "FaceRecognitionEngine",
        "onnxruntime",
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ],
      path: "Sources/face_recognition_sdk",
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath(".")
      ],
      linkerSettings: [
        .linkedFramework("UIKit"),
        .linkedFramework("Foundation"),
        .linkedLibrary("c++")
      ]
    )
  ]
)
