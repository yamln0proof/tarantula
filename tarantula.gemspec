# frozen_string_literal: true

require_relative "lib/tarantula/version"

Gem::Specification.new do |spec|
  spec.name = "tarantula"
  spec.version = Tarantula::VERSION
  spec.authors = ["Nabil Ahmed"]
  spec.email = ["sun.swadhin101@gmail.com"]

  spec.summary = "Terminal-based, domain-scoped web crawler"
  spec.description = "An interactive terminal crawler that discovers pages and files on supplied domains."
  spec.homepage = "https://github.com/yamln0proof/tarantula"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  tracked_files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end
  spec.files = tracked_files.uniq.reject do |f|
    (f == gemspec) ||
      %w[bin/setup bin/console bin/uninstall].include?(f) ||
      f.start_with?(*%w[test/ spec/ features/ .git appveyor Gemfile data/])
  end
  spec.bindir = "bin"
  spec.executables = ["tarantula"]
  spec.require_paths = ["lib"]

  # Database clients
  spec.add_dependency "bigdecimal"
  spec.add_dependency "curses", "~> 1.7.0"
  spec.add_dependency "mongo", "~> 2.21"
  spec.add_dependency "nokogiri", "~> 1.18"
  spec.add_dependency "redis", "~> 5.4"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
