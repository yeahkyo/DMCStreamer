#
# Be sure to run `pod lib lint DMCStreamer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DMCStreamer'
  s.version          = '0.1.0'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.summary          = 'Lightweight iOS stream player based on Core Audio.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

#  s.description      = <<-DESC
#                       DESC

  s.homepage         = 'https://github.com/yeahkyo/DMCStreamer'
  s.author           = { 'Yeah' => 'zyeah61@gmail.com' }
  s.source           = { :git => 'https://github.com/yeahkyo/DMCStreamer.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '7.0'
  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.source_files = 'DMCStreamer/Classes/**/*.{h,m}'
  
  s.frameworks = 'Foundation', 'AudioToolbox', 'AVFoundation'
end
