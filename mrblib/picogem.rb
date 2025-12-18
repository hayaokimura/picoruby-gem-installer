# picogem - PicoRuby Gem Manager
# Main entry point

VERSION = "0.5.0"
REPO_OWNER = "hayaokimura"
REPO_NAME = "picoruby-gem-installer"

$debug = false

def print_usage
  puts "Usage: picogem <command> [options]"
  puts ""
  puts "Commands:"
  puts "  add <package>    Download a PicoRuby gem"
  puts "  list             List available runtime gems"
  puts "  sync <storage>   Sync local .rb files to storage"
  puts ""
  puts "Options:"
  puts "  -h, --help       Show this help"
  puts "  -v, --version    Show version"
  puts "  --debug          Show debug output"
  puts ""
  puts "Example:"
  puts "  picogem add picoruby-mcp3424"
  puts "  picogem list"
  puts "  picogem sync /mnt/pico"
  puts ""
  puts "Run 'picogem <command> --help' for more information on a command."
end

def print_version
  puts VERSION
end

def check_for_updates
  begin
    latest_version = GitHubDownloader.fetch_latest_release(REPO_OWNER, REPO_NAME)
    return if latest_version.nil?
    return if latest_version == VERSION

    # バージョン比較（新しいバージョンがある場合のみ通知）
    current_parts = VERSION.split('.').map(&:to_i)
    latest_parts = latest_version.split('.').map(&:to_i)

    is_newer = false
    latest_parts.each_with_index do |part, i|
      current_part = current_parts[i] || 0
      if part > current_part
        is_newer = true
        break
      elsif part < current_part
        break
      end
    end

    if is_newer
      puts "New version available: #{latest_version} (current: #{VERSION})"
      puts "To update, run: curl -fsSL https://raw.githubusercontent.com/#{REPO_OWNER}/#{REPO_NAME}/main/install.sh | bash"
      puts ""
    end
  rescue
    # ネットワークエラー等は無視して続行
  end
end

# メイン実行
if __FILE__ == $PROGRAM_NAME || ARGV.length > 0
  # --debug オプションをチェック
  if ARGV.include?("--debug")
    $debug = true
    ARGV.delete("--debug")
  end

  # 最初にアップデートチェック
  check_for_updates

  if ARGV.length == 0
    print_usage
    exit 1
  end

  command = ARGV[0]
  args = ARGV[1..-1] || []

  case command
  when "add"
    Commands.add(args)
  when "list"
    Commands.list(args)
  when "sync"
    Commands.sync(args)
  when "-h", "--help"
    print_usage
    exit 0
  when "-v", "--version"
    print_version
    exit 0
  else
    puts "Error: Unknown command '#{command}'"
    puts ""
    print_usage
    exit 1
  end
end
