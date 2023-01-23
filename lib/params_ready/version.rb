module ParamsReady
  VERSION = '0.0.9'.freeze

  def self.gem_version
    ::Gem::Version.new(VERSION)
  end
end
