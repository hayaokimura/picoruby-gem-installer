# picogem - PicoRuby Gem Manager
# GitHubリポジトリからPicoRuby gemをダウンロード・管理

class GitHubDownloader
  GITHUB_RAW_BASE = "https://raw.githubusercontent.com"
  GITHUB_API_BASE = "https://api.github.com"

  def initialize(owner, repo, branch = "main")
    @owner = owner
    @repo = repo
    @branch = branch
    @curl = Curl.new
  end

  # ディレクトリ内のファイル一覧を取得（GitHub API使用）
  def list_directory(path)
    url = "#{GITHUB_API_BASE}/repos/#{@owner}/#{@repo}/contents/#{path}?ref=#{@branch}"

    puts "DEBUG: Requesting URL: #{url}"
    response = @curl.get(url, default_headers)
    puts "DEBUG: Response status: #{response.status_code}"

    if response.status_code != 200
      puts "Error: Failed to list directory (HTTP #{response.status_code})"
      puts "DEBUG: Response body: #{response.body}"
      return nil
    end

    JSON.parse(response.body)
  end

  # 単一ファイルをダウンロード
  def download_file(remote_path, local_path)
    url = "#{GITHUB_RAW_BASE}/#{@owner}/#{@repo}/#{@branch}/#{remote_path}"

    puts "Downloading: #{remote_path}"
    response = @curl.get(url, default_headers)

    if response.status_code != 200
      puts "  Error: HTTP #{response.status_code}"
      return false
    end

    # ディレクトリが存在しない場合は作成
    dir = File.dirname(local_path)
    mkdir_p(dir) unless dir == "." || dir == ""

    File.open(local_path, 'wb') do |f|
      f.write(response.body)
    end

    puts "  Saved: #{local_path} (#{response.body.length} bytes)"
    true
  end

  # ディレクトリを再帰的にダウンロード
  def download_directory(remote_dir, local_dir)
    puts "Fetching directory listing: #{remote_dir}"

    items = list_directory(remote_dir)
    return false if items.nil?

    items.each do |item|
      name = item["name"]
      type = item["type"]
      remote_path = item["path"]
      local_path = "#{local_dir}/#{name}"

      if type == "file"
        download_file(remote_path, local_path)
      elsif type == "dir"
        download_directory(remote_path, local_path)
      end
    end

    true
  end

  private

  def default_headers
    {
      'User-Agent' => 'picogem/1.0',
      'Accept' => 'application/vnd.github.v3+json'
    }
  end

  def mkdir_p(path)
    parts = path.split('/')
    current = ""
    parts.each do |part|
      current = current.empty? ? part : "#{current}/#{part}"
      Dir.mkdir(current) unless File.exist?(current)
    end
  end
end

# ============================
# コマンドハンドラー
# ============================
module Commands
  # add コマンド - gemをダウンロード
  def self.add(args)
    opts = parse_add_options(args)

    if opts[:package].nil?
      print_add_usage
      exit 1
    end

    puts "=== picogem add ==="
    puts "Repository: #{opts[:owner]}/#{opts[:repo]}"
    puts "Branch: #{opts[:branch]}"
    puts "Package: #{opts[:package]}"
    puts "Source: #{opts[:directory]}"
    puts "Output: #{opts[:output]}/#{opts[:package]}"
    puts ""

    downloader = GitHubDownloader.new(opts[:owner], opts[:repo], opts[:branch])

    # パッケージディレクトリごと取得
    output_path = "#{opts[:output]}/#{opts[:package]}"
    success = downloader.download_directory(opts[:directory], output_path)

    if success
      puts ""
      puts "Download completed successfully!"
    else
      puts ""
      puts "Download failed."
      exit 1
    end
  end

  # list コマンド - picoruby/picoruby の runtime_gems を表示
  def self.list(args)
    opts = parse_list_options(args)

    puts "=== PicoRuby Runtime Gems ==="
    puts "Repository: #{opts[:owner]}/#{opts[:repo]}"
    puts "Branch: #{opts[:branch]}"
    puts "Directory: #{opts[:base_dir]}"
    puts ""

    downloader = GitHubDownloader.new(opts[:owner], opts[:repo], opts[:branch])
    items = downloader.list_directory(opts[:base_dir])

    if items.nil?
      puts "Failed to fetch gem list."
      exit 1
    end

    gems = items.select { |item| item["type"] == "dir" }

    if gems.empty?
      puts "No gems found."
    else
      puts "Available gems:"
      gems.each do |gem|
        puts "  #{gem["name"]}"
      end
      puts ""
      puts "Total: #{gems.length} gems"
    end
  end

  private

  def self.parse_add_options(args)
    opts = {
      owner: "picoruby",
      repo: "picoruby",
      branch: "master",
      base_dir: "runtime_gems",
      output: "lib",
      package: nil
    }

    i = 0
    positional = []

    while i < args.length
      arg = args[i]

      case arg
      when "-r", "--repo"
        i += 1
        repo_arg = args[i]
        if repo_arg && repo_arg.include?("/")
          parts = repo_arg.split("/", 2)
          opts[:owner] = parts[0]
          opts[:repo] = parts[1]
        end
      when "-b", "--branch"
        i += 1
        opts[:branch] = args[i]
      when "-d", "--dir"
        i += 1
        opts[:base_dir] = args[i]
      when "-o", "--output"
        i += 1
        opts[:output] = args[i]
      when "-h", "--help"
        print_add_usage
        exit 0
      else
        positional << arg unless arg.start_with?("-")
      end

      i += 1
    end

    opts[:package] = positional[0] if positional.length > 0
    opts[:directory] = "#{opts[:base_dir]}/#{opts[:package]}" if opts[:package]

    opts
  end

  def self.parse_list_options(args)
    opts = {
      owner: "picoruby",
      repo: "picoruby",
      branch: "master",
      base_dir: "runtime_gems"
    }

    i = 0

    while i < args.length
      arg = args[i]

      case arg
      when "-r", "--repo"
        i += 1
        repo_arg = args[i]
        if repo_arg && repo_arg.include?("/")
          parts = repo_arg.split("/", 2)
          opts[:owner] = parts[0]
          opts[:repo] = parts[1]
        end
      when "-b", "--branch"
        i += 1
        opts[:branch] = args[i]
      when "-d", "--dir"
        i += 1
        opts[:base_dir] = args[i]
      when "-h", "--help"
        print_list_usage
        exit 0
      end

      i += 1
    end

    opts
  end

  def self.print_add_usage
    puts "Usage: picogem add <package> [options]"
    puts ""
    puts "Options:"
    puts "  -r, --repo OWNER/REPO  Repository (default: picoruby/picoruby)"
    puts "  -b, --branch BRANCH    Branch name (default: master)"
    puts "  -d, --dir DIR          Base directory in repo (default: runtime_gems)"
    puts "  -o, --output DIR       Output directory (default: lib)"
    puts "  -h, --help             Show this help"
    puts ""
    puts "Example:"
    puts "  picogem add picoruby-mcp3424"
    puts "  picogem add picoruby-gpio -o ./gems"
    puts "  picogem add mruby-pca9685 -r mruby/mruby -d mrbgems -b master"
  end

  def self.print_list_usage
    puts "Usage: picogem list [options]"
    puts ""
    puts "Options:"
    puts "  -r, --repo OWNER/REPO  Repository (default: picoruby/picoruby)"
    puts "  -b, --branch BRANCH    Branch name (default: master)"
    puts "  -d, --dir DIR          Directory to list (default: runtime_gems)"
    puts "  -h, --help             Show this help"
    puts ""
    puts "Example:"
    puts "  picogem list"
    puts "  picogem list -r mruby/mruby -d mrbgems"
  end
end

# ============================
# メイン処理
# ============================
def print_usage
  puts "Usage: picogem <command> [options]"
  puts ""
  puts "Commands:"
  puts "  add <package>    Download a PicoRuby gem"
  puts "  list             List available runtime gems"
  puts ""
  puts "Options:"
  puts "  -h, --help       Show this help"
  puts "  -v, --version    Show version"
  puts ""
  puts "Example:"
  puts "  picogem add picoruby-mcp3424"
  puts "  picogem list"
  puts ""
  puts "Run 'picogem <command> --help' for more information on a command."
end

def print_version
  puts "picogem version 1.0.0"
end

# メイン実行
if __FILE__ == $PROGRAM_NAME || ARGV.length > 0
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
