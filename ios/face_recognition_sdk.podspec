#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'face_recognition_sdk'
  s.version          = '0.1.0'
  s.summary          = 'FacePlugin Face Recognition SDK for Flutter'
  s.description      = <<-DESC
FacePlugin Face Recognition SDK — on-device face detect, templates, VideoWorker.
                       DESC
  s.homepage         = 'https://faceplugin.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'FacePlugin' => 'info@faceplugin.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'face_recognition_sdk/Sources/face_recognition_sdk/**/*.{h,m,mm}'
  s.public_header_files = 'face_recognition_sdk/Sources/face_recognition_sdk/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.libraries = 'c++'

  # Prefer .xcframework (CocoaPods links these into the pod target). Plain
  # .framework is kept as a fallback drop from Drive, but alone it often only
  # reaches the app OTHER_LDFLAGS and leaves undefined symbols when building
  # face_recognition_sdk.framework under use_frameworks!.
  frameworks = []
  missing = []
  %w[
    facerecognitionsdk
    FaceRecognitionEngine
    onnxruntime
  ].each do |base|
    xc = File.join(__dir__, 'Frameworks', "#{base}.xcframework")
    fw = File.join(__dir__, 'Frameworks', "#{base}.framework")
    if File.directory?(xc)
      frameworks << "Frameworks/#{base}.xcframework"
    elsif File.directory?(fw)
      frameworks << "Frameworks/#{base}.framework"
    else
      missing << fw
    end
  end
  unless missing.empty?
    raise Pod::Informative, <<~MSG

      Missing Face Recognition iOS frameworks (#{missing.size}):
      #{missing.map { |p| "  - #{p}" }.join("\n")}

      Unzip the Drive iOS pack into ios/Frameworks/ (plugin root, not example/ios),
      then run: dart run tool/bootstrap.dart && cd example/ios && pod install
    MSG
  end
  s.vendored_frameworks = frameworks

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    # Ensure the plugin dylib loads the native SDK (needed when vendoring .framework).
    'OTHER_LDFLAGS' => '$(inherited) -framework "facerecognitionsdk" -framework "FaceRecognitionEngine" -framework "onnxruntime" -lc++'
  }
  s.swift_version = '5.0'
end
