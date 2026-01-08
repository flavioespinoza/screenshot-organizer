class ScreenshotOrganizer < Formula
  desc "Auto-organize and analyze screenshots with GPT-4V vision"
  homepage "https://github.com/flavioespinoza/screenshot-organizer"
  url "https://github.com/flavioespinoza/screenshot-organizer/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on "fswatch"
  depends_on "jq"

  def install
    bin.install "screenshot-organizer.sh" => "screenshot-organizer"

    # Install launchd plist template
    prefix.install "com.screenshot-organizer.plist.template"
  end

  def caveats
    <<~EOS
      To use screenshot-organizer, you need to set your OpenAI API key:
        export OPENAI_API_KEY="sk-your-key-here"

      Add this to your ~/.zshrc or ~/.bashrc for persistence.

      To install and start the background service:
        # Copy the plist template
        cp #{opt_prefix}/com.screenshot-organizer.plist.template ~/Library/LaunchAgents/com.screenshot-organizer.plist

        # Edit the plist to add your API key and screenshots directory
        # Then load the daemon:
        launchctl load ~/Library/LaunchAgents/com.screenshot-organizer.plist

      Or run manually:
        screenshot-organizer watch ~/Desktop/Screenshots
    EOS
  end

  test do
    system "#{bin}/screenshot-organizer", "status"
  end
end
