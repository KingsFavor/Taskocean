cask "taskocean" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/KingsFavor/Taskocean/releases/download/v#{version}/TaskOcean-#{version}.dmg",
      verified: "github.com/KingsFavor/Taskocean/"
  name "TaskOcean"
  desc "Always-on-top Google Tasks utility for macOS"
  homepage "https://github.com/KingsFavor/Taskocean"

  depends_on macos: ">= :sonoma"

  app "TaskOcean.app"

  zap trash: [
    "~/Library/Application Support/com.dws.taskocean",
    "~/Library/Caches/com.dws.taskocean",
    "~/Library/HTTPStorages/com.dws.taskocean",
    "~/Library/Preferences/com.dws.taskocean.plist",
  ]
end
