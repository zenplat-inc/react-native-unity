require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

Pod::Spec.new do |s|
  s.name         = "react-native-unity"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "12.4" }
  s.source       = { :git => "https://github.com/azesmway/react-native-unity.git", :tag => "#{s.version}" }

  # 非再帰パターンで ios/ 直下のファイルのみを収集する
  # ios/**/*.{h,m,mm} だと xcframework の両スライスのヘッダーを拾い
  # "Multiple commands produce" エラーが発生するため
  s.source_files = "ios/*.{h,m,mm}"

  # CocoaPods は vendored_frameworks を宣言したポッド自身の xcconfig に
  # ${PODS_XCFRAMEWORKS_BUILD_DIR}/react-native-unity を自動追加しないため明示指定
  s.pod_target_xcconfig = {
    "FRAMEWORK_SEARCH_PATHS" => "\"$(PODS_XCFRAMEWORKS_BUILD_DIR)/react-native-unity\""
  }

  # Use install_modules_dependencies helper to install the dependencies if React Native version >=0.71.0.
  # See https://github.com/facebook/react-native/blob/febf6b7f33fdb4904669f99d795eba4c0f95d7bf/scripts/cocoapods/new_architecture.rb#L79.
  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"

    # Don't install the dependencies when we run `pod install` in the old architecture.
    if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
      s.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"
      s.pod_target_xcconfig = {
          "DEFINES_MODULE" => "YES",
          "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\"",
          "FRAMEWORK_SEARCH_PATHS" => "\"$(PODS_XCFRAMEWORKS_BUILD_DIR)/react-native-unity\"",
          "OTHER_CPLUSPLUSFLAGS" => "-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1",
          "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
      }
      s.dependency "React-RCTFabric"
      s.dependency "React-Codegen"
      s.dependency "RCT-Folly"
      s.dependency "RCTRequired"
      s.dependency "RCTTypeSafety"
      s.dependency "ReactCommon/turbomodule/core"
    end
  end

  # prepare_command は pod install 時に一度だけ実行される
  # - rm -rf で既存ファイルを先に削除し cp -R のネストを防ぐ
  # - xcframework が存在する場合はそのままコピー
  # - framework のみの場合は xcodebuild で xcframework に変換（シミュレーター対応）
  s.prepare_command =
  <<-CMD
    rm -rf ios/UnityFramework.framework ios/UnityFramework.xcframework
    if [ -d ../../../unity/builds/ios/UnityFramework.xcframework ]; then
      cp -R ../../../unity/builds/ios/UnityFramework.xcframework ios/
    elif [ -d ../../../unity/builds/ios/UnityFramework.framework ]; then
      xcodebuild -create-xcframework \
        -framework ../../../unity/builds/ios/UnityFramework.framework \
        -output ios/UnityFramework.xcframework
    fi
  CMD

  # File.exist? は prepare_command 実行前に評価されるため条件分岐できない。
  # prepare_command が必ず xcframework を生成するため、常に xcframework を指定する。
  s.vendored_frameworks = ["ios/UnityFramework.xcframework"]
end
