cask "mouseportal" do
  version "0.1.0"
  sha256 "9eb4c7261d81813e126c3c2db8fe716a2f511a57c52db044b400a9c920feec1e"

  url "https://github.com/paolo-05/mouse-portal-macos/releases/download/v#{version}/MousePortal-#{version}-macOS.zip"
  name "MousePortal"
  desc "Connect display-edge segments so the pointer can cross gaps"
  homepage "https://github.com/paolo-05/mouse-portal-macos"

  depends_on macos: :ventura

  app "MousePortal.app"

  uninstall quit: "io.mouseportal.MousePortal"

  zap trash: [
    "~/Library/Preferences/io.mouseportal.MousePortal.plist",
    "~/Library/Saved Application State/io.mouseportal.MousePortal.savedState",
  ]

  caveats do
    unsigned_accessibility
  end
end
