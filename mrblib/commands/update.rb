# Commands::update - Update picogem CLI
module Commands
  # update command - Update picogem to the latest version
  def self.update(args)
    opts = parse_update_options(args)

    puts "=== picogem update ==="
    puts ""

    # Get latest version
    puts "Checking for updates..."
    latest_version = GitHubDownloader.fetch_latest_release(REPO_OWNER, REPO_NAME)

    if latest_version.nil?
      puts "Error: Failed to get latest version"
      exit 1
    end

    puts "Current version: #{VERSION}"
    puts "Latest version:  #{latest_version}"
    puts ""

    # Compare versions
    if version_compare(VERSION, latest_version) >= 0
      puts "You are already using the latest version."
      exit 0
    end

    puts "New version available!"
    puts ""

    # Detect platform
    platform = detect_platform
    if platform.nil?
      puts "Error: Unsupported platform"
      exit 1
    end
    puts "Platform: #{platform}"

    # Download URL
    download_url = "https://github.com/#{REPO_OWNER}/#{REPO_NAME}/releases/download/v#{latest_version}/picogem-#{platform}"
    puts "Download URL: #{download_url}"
    puts ""

    # Download binary
    puts "Downloading..."
    curl = Curl.new
    headers = {
      'User-Agent' => 'picogem/1.0',
      'Accept' => 'application/octet-stream'
    }

    github_token = ENV['GITHUB_TOKEN']
    if github_token && !github_token.empty?
      headers['Authorization'] = "Bearer #{github_token}"
    end

    response = curl.get(download_url, headers)

    if response.status_code != 200
      puts "Error: Failed to download (HTTP #{response.status_code})"
      exit 1
    end

    binary_data = response.body
    puts "Downloaded #{binary_data.length} bytes"

    # Determine install path
    install_path = get_install_path
    if install_path.nil?
      puts "Error: Could not determine install path"
      exit 1
    end
    puts "Install path: #{install_path}"

    # Write to temporary file first
    tmp_path = "#{install_path}.new"

    File.open(tmp_path, 'wb') do |f|
      f.write(binary_data)
    end
    puts "Saved to: #{tmp_path}"

    # Move to install path
    begin
      # Remove old binary
      File.delete(install_path) if File.exist?(install_path)
      # Rename new binary
      File.rename(tmp_path, install_path)
    rescue => e
      puts ""
      puts "Error: Failed to replace binary"
      puts "Please run manually:"
      puts "  sudo mv #{tmp_path} #{install_path}"
      puts "  sudo chmod +x #{install_path}"
      exit 1
    end

    # Make executable (if File.chmod is available)
    begin
      File.chmod(0755, install_path)
    rescue NoMethodError
      puts ""
      puts "Note: Could not set executable permission."
      puts "Please run: chmod +x #{install_path}"
    end

    puts ""
    puts "Update completed successfully!"
    puts "picogem has been updated to v#{latest_version}"
  end

  # Compare version strings
  # Returns: -1 if a < b, 0 if a == b, 1 if a > b
  def self.version_compare(a, b)
    a_parts = a.split('.').map(&:to_i)
    b_parts = b.split('.').map(&:to_i)

    max_len = [a_parts.length, b_parts.length].max

    max_len.times do |i|
      a_part = a_parts[i] || 0
      b_part = b_parts[i] || 0

      if a_part < b_part
        return -1
      elsif a_part > b_part
        return 1
      end
    end

    0
  end

  # Detect platform (linux-x86_64, darwin-x86_64, darwin-arm64)
  def self.detect_platform
    # Try to read from /etc/os-release or uname
    os = nil
    arch = nil

    # Detect OS
    if File.exist?('/etc/os-release')
      os = 'linux'
    elsif File.exist?('/System/Library/CoreServices/SystemVersion.plist')
      os = 'darwin'
    else
      # Fallback: check for common Linux/macOS paths
      if File.exist?('/proc')
        os = 'linux'
      elsif File.exist?('/Applications')
        os = 'darwin'
      end
    end

    return nil if os.nil?

    # Detect architecture by checking pointer size or binary format
    # This is a workaround since we can't easily call uname from mruby
    # Assume x86_64 for Linux, try to detect arm64 for macOS
    if os == 'linux'
      arch = 'x86_64'
    elsif os == 'darwin'
      # Check for Apple Silicon indicator
      if File.exist?('/opt/homebrew')
        arch = 'arm64'
      else
        arch = 'x86_64'
      end
    end

    "#{os}-#{arch}"
  end

  # Get the install path of picogem
  def self.get_install_path
    # Check common installation paths
    paths = [
      '/usr/local/bin/picogem',
      "#{ENV['HOME']}/.local/bin/picogem"
    ]

    paths.each do |path|
      return path if File.exist?(path)
    end

    # Default to ~/.local/bin/picogem
    local_bin = "#{ENV['HOME']}/.local/bin"
    mkdir_p(local_bin)
    "#{local_bin}/picogem"
  end

  def self.parse_update_options(args)
    opts = {}

    args.each do |arg|
      case arg
      when "-h", "--help"
        print_update_usage
        exit 0
      end
    end

    opts
  end

  def self.print_update_usage
    puts "Usage: picogem update [options]"
    puts ""
    puts "Update picogem CLI to the latest version."
    puts ""
    puts "Options:"
    puts "  -h, --help    Show this help"
    puts ""
    puts "Example:"
    puts "  picogem update"
  end
end
