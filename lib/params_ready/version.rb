module ParamsReady
  VERSION = '0.0.7'.freeze

  def self.gem_version
    ::Gem::Version.new(VERSION)
  end
end