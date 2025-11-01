platform :ios, '16.0'

target 'Liquid Pay' do
  use_frameworks!
  pod 'razorpay-pod', '~> 1.4.6'
  pod 'Google-Mobile-Ads-SDK'
end

post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      # Fix code signing for pods
      config.build_settings['CODE_SIGN_IDENTITY'] = ''
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['CODE_SIGN_ENTITLEMENTS'] = ''
    end
  end
end
