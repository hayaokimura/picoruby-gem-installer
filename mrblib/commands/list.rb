# Commands::list - List available runtime gems
module Commands
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
