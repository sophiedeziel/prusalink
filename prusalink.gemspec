# frozen_string_literal: true

require_relative "lib/prusalink/version"

Gem::Specification.new do |spec|
  spec.name          = "prusalink"
  spec.version       = Prusalink::VERSION
  spec.authors       = ["Sophie Déziel"]
  spec.email         = ["courrier@sophiedeziel.com"]

  spec.summary       = "A type-safe Ruby wrapper for the PrusaLink REST API with full Sorbet integration."
  spec.description   = "A type-safe Ruby wrapper for PrusaLink, the local web API of Prusa 3D printers " \
                       "(MK4, MK3.9, MK3.5, XL, MINI, Core One and MK3 with a Raspberry Pi). Supports " \
                       "printer status, jobs, storage, transfers and file uploads with HTTP Digest authentication."
  spec.homepage      = "https://github.com/sophiedeziel/prusalink"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sophiedeziel/prusalink"
  spec.metadata["changelog_uri"] = "https://github.com/sophiedeziel/prusalink/blob/main/CHANGELOG.md"

  # Ship only the library and its docs: specs, Sorbet RBIs and dev tooling stay in the repo
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z lib README.md CHANGELOG.md LICENSE.txt`.split("\x0")
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_dependency "faraday", ">= 2.2", "< 3"
  spec.add_dependency "net-http-digest_auth", "~> 1.4"
  spec.add_dependency "sorbet-runtime", ">= 0.5.10908", "< 0.7.0"
  spec.add_dependency "zeitwerk", "~> 2.6"

  spec.metadata["rubygems_mfa_required"] = "true"
end
