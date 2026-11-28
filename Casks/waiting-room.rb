cask "waiting-room" do
  version "0.2.2"
  sha256 "fc95caa0cfc123eac67b782b81810ba22c5395c3f0b55c48a7785e1bbafc0b6d"

  url "https://github.com/DinoCodes-Potter/Waiting-Room/releases/download/v#{version}/WaitingRoom-#{version}.dmg"
  name "Waiting Room"
  desc "Menu bar app that watches part of your screen and tells you when it stops changing"
  homepage "https://dinocodes-potter.github.io/Waiting-Room/"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "Waiting Room.app"

  zap trash: [
    "~/Library/Preferences/com.example.waitingroom.plist",
  ]

  caveats <<~EOS
    Waiting Room is not notarized. If macOS refuses to open it, go to
    System Settings > Privacy & Security and choose Open Anyway.
    Then allow Screen Recording for it in System Settings.
  EOS
end
