cask "mouseportal" do
  version "0.2.0"
  sha256 "149a534ef7177cf375ab79c871b93a8d47234bf04c5e60f32db2987c24098f83"

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
