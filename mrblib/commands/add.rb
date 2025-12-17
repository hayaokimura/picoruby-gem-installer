# Commands::add - Download a PicoRuby gem
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
end
