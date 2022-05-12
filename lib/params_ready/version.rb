module ParamsReady
  VERSION = '0.0.8'.freeze

  def self.gem_version
    ::Gem::Version.new(VERSION)
  end
end