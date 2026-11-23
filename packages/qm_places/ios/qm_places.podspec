Pod::Spec.new do |s|
  s.name             = 'qm_places'
  s.version          = '0.0.1'
  s.summary          = 'Apple Maps local search for Qimen Compass.'
  s.description      = 'MKLocalSearch over a Flutter method channel (qm/places).'
  s.homepage         = 'https://github.com/lawrence124875/qimen-compass'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'LC Lab' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.frameworks       = 'MapKit'
  s.ios.deployment_target = '15.0'
  s.swift_version    = '5.0'
end
