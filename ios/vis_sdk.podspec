Pod::Spec.new do |s|
  s.name             = 'vis_sdk'
  s.version          = '1.0.4'
  s.summary          = 'Flutter plugin for the Vis identity verification SDKs.'
  s.description      = 'Wraps the native Vis iOS SDK (VisSDK) for Flutter apps.'
  s.homepage         = 'https://github.com/revolution-uz/vis-sdk-flutter'
  s.license          = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author           = 'vis.uz'
  s.source           = { :path => '.' }
  s.source_files     = 'vis_sdk/Sources/vis_sdk/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'VisSDK', '1.0.4'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.resource_bundles = { 'vis_sdk_privacy' => ['vis_sdk/Sources/vis_sdk/PrivacyInfo.xcprivacy'] }
end
