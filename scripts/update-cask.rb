#!/usr/bin/env ruby
# frozen_string_literal: true

abort "Usage: update-cask.rb VERSION SHA256 [CASK_PATH]" unless (2..3).cover?(ARGV.length)

version, sha256, cask_path = ARGV
cask_path ||= File.expand_path("../Casks/mouseportal.rb", __dir__)

abort "Invalid semantic version: #{version}" unless version.match?(/\A\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?\z/)
abort "Invalid SHA-256: #{sha256}" unless sha256.match?(/\A[0-9a-f]{64}\z/)
abort "Cask not found: #{cask_path}" unless File.file?(cask_path)

contents = File.read(cask_path)
updated = contents.sub(/^  version ".*"$/, %(  version "#{version}"))
updated = updated.sub(/^  sha256 (?:"[0-9a-f]{64}"|:no_check)$/, %(  sha256 "#{sha256}"))

abort "Could not update version in #{cask_path}" unless updated.include?(%(  version "#{version}"))
abort "Could not update SHA-256 in #{cask_path}" unless updated.include?(%(  sha256 "#{sha256}"))

File.write(cask_path, updated)
