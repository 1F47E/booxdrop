class Booxdrop < Formula
  desc "Native macOS MTP file manager for Boox e-readers — GUI + CLI"
  homepage "https://github.com/1F47E/booxdrop"
  url "https://github.com/1F47E/booxdrop.git", branch: "main"
  version "1.0.0"
  license "MIT"

  depends_on "libmtp"
  depends_on "xcodegen" => :build
  depends_on :macos => :sonoma

  def install
    system "xcodegen", "generate"
    system "xcodebuild", "-scheme", "booxcp",
           "-configuration", "Release",
           "-derivedDataPath", buildpath/"build",
           "HEADER_SEARCH_PATHS=#{Formula["libmtp"].opt_include}",
           "LIBRARY_SEARCH_PATHS=#{Formula["libmtp"].opt_lib}",
           "build"
    bin.install buildpath/"build/Build/Products/Release/booxcp"
  end

  def caveats
    <<~EOS
      The CLI tool `booxcp` is installed.

      For the GUI app (BooxDrop.app), build manually:
        cd $(brew --prefix)/opt/booxdrop
        xcodegen generate
        xcodebuild -scheme BooxDrop -configuration Release build

      Your device must be in MTP/File Transfer mode.
    EOS
  end

  test do
    assert_match "booxcp", shell_output("#{bin}/booxcp help")
  end
end
