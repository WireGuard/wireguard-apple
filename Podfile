platform :ios, '10.0'

use_frameworks!

swift_version = "4.0"

target 'Wireguard' do
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'SwiftLint'
  pod 'PromiseKit/CorePromise'
  pod 'KeychainSwift'
  pod 'Moya'
  pod 'Disk'
  pod 'AlamofireImage'
  pod 'BNRCoreDataStack'
  pod 'NVActivityIndicatorView'

  post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-Wireguard/Pods-Wireguard-Acknowledgements.plist', 'Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)

  end
end

