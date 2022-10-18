Pod::Spec.new do |s|
  s.name             = 'WhimCore'
  s.version          = '0.1.0'
  s.summary          = 'Whim 2 Core Utils.'
  s.swift_version    = '5.2'
  s.homepage         = 'https://github.com/maasglobal/whim-ios'
  s.license          = { :type => 'UNLICENSED' }
  s.author           = { 'MaaS Global' => 'tech@maas.fi' }
  s.source           = { :git => 'https://github.com/maasglobal/whim-ios-core.git', :tag => "wc-#{s.version.to_s}"}

  s.ios.deployment_target = '14.0'

  s.source_files = 'Sources/WhimCore/**/*.swift'
  s.resource_bundles = {
    'WhimCoreResources' => ['Sources/WhimCore/**/*.xib', 'Sources/WhimCore/Resources/*.xcassets']
  }

  s.frameworks = 'UIKit', 'MapKit'

  s.dependency 'RxSwift', '~> 6'
  s.dependency 'RxCocoa', '~> 6'
  s.dependency 'SDWebImage', '5.13.4' # MIT
  s.dependency 'WhimUtils'

  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/WhimCoreTests/**/*'
    
    ts.dependency 'Quick', '~> 3'
    ts.dependency 'Nimble', '~> 9'
    ts.dependency 'RxTest', '~> 6'
    ts.dependency 'RxBlocking', '~> 6'
    ts.dependency 'SwiftyMock', '0.2.3'
    ts.dependency 'WhimRandom'

    ts.info_plist = {
      'NSPrincipalClass' => 'WhimCore_Unit_Tests.RandomSeed'
    }

    ts.scheme = {
      :code_coverage => true
    }
  end
end
