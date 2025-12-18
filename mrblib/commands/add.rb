# Commands::add - Download and compile a mrbgem from GitHub
module Commands
  # add コマンド - GitHub から mrbgem をダウンロードしてコンパイル
  def self.add(args)
    opts = parse_add_options(args)

    # --repo も gem名も指定されていない場合はヘルプを表示
    if opts[:gem_name].nil? && opts[:repo_url].nil?
      print_add_usage
      exit 1
    end

    # モードを決定
    if opts[:repo_url]
      # --repo モード: 指定されたリポジトリの mrblib を使用
      parse_repo_url(opts)
      opts[:mrblib_path] = "mrblib"
      opts[:branch] ||= "main"
    else
      # gem名モード: picoruby/picoruby の mrbgems/<gem_name>/mrblib を使用
      opts[:owner] = "picoruby"
      opts[:repo] = "picoruby"
      opts[:branch] ||= "master"
      opts[:mrblib_path] = "mrbgems/#{opts[:gem_name]}/mrblib"
    end

    puts "=== picogem add ==="
    puts "Repository: #{opts[:owner]}/#{opts[:repo]}"
    puts "Branch: #{opts[:branch]}"
    puts "Source: #{opts[:mrblib_path]}"
    puts "Output: #{opts[:output]}"
    puts ""

    downloader = GitHubDownloader.new(opts[:owner], opts[:repo], opts[:branch])

    # mrblib ディレクトリの存在確認
    puts "Checking mrblib directory: #{opts[:mrblib_path]}"

    mrblib_items = downloader.list_directory(opts[:mrblib_path])
    if mrblib_items.nil?
      puts "Error: mrblib directory not found at '#{opts[:mrblib_path]}'"
      puts "Make sure the repository has a standard mrbgem structure with a mrblib directory."
      exit 1
    end

    # src ディレクトリに *.c ファイルがあるかチェック
    if opts[:repo_url]
      src_path = "src"
    else
      src_path = "mrbgems/#{opts[:gem_name]}/src"
    end
    src_items = downloader.list_directory(src_path, true)

    if src_items
      c_files = src_items.select { |item| item["type"] == "file" && item["name"].end_with?(".c") }
      if c_files.length > 0
        puts ""
        puts "Warning: This gem contains C source files in src/ directory:"
        c_files.each { |f| puts "  - #{f['name']}" }
        puts ""
        puts "C extensions cannot be used as Runtime Gems."
        puts "Only the Ruby files from mrblib/ will be compiled."
        print "Continue anyway? [y/N]: "

        response = gets
        if response.nil? || !response.strip.downcase.start_with?("y")
          puts "Aborted."
          exit 0
        end
        puts ""
      end
    end

    # 一時ディレクトリを作成（タイムスタンプベース）
    temp_dir = ".picogem_temp_#{Time.now.to_i}"
    mkdir_p(temp_dir)

    begin
      # mrblib 内の *.rb ファイルをダウンロード
      rb_files = collect_rb_files(downloader, opts[:mrblib_path], mrblib_items)

      if rb_files.empty?
        puts "Error: No .rb files found in mrblib directory"
        exit 1
      end

      puts "Found #{rb_files.length} Ruby file(s) to compile:"
      rb_files.each { |f| puts "  - #{f[:name]}" }
      puts ""

      # 出力ディレクトリを作成
      mkdir_p(opts[:output])

      # 各 .rb ファイルをダウンロードしてコンパイル
      rb_files.each do |rb_file|
        temp_rb_path = "#{temp_dir}/#{rb_file[:name]}"
        # .rb -> .mrb に変換
        mrb_name = rb_file[:name]
        if mrb_name.end_with?(".rb")
          mrb_name = mrb_name[0, mrb_name.length - 3] + ".mrb"
        end
        output_mrb_path = "#{opts[:output]}/#{mrb_name}"

        # ダウンロード
        success = downloader.download_file(rb_file[:path], temp_rb_path)
        unless success
          puts "Error: Failed to download #{rb_file[:path]}"
          exit 1
        end

        # コンパイル
        puts "Compiling: #{rb_file[:name]} -> #{output_mrb_path}"
        begin
          Mrbc.compile(temp_rb_path, output_mrb_path)
          puts "  Compiled successfully"
        rescue => e
          puts "Error: Failed to compile #{rb_file[:name]}: #{e.message}"
          exit 1
        end
      end

      puts ""
      puts "Successfully added #{rb_files.length} compiled gem file(s) to #{opts[:output]}/"

    ensure
      # 一時ディレクトリを削除
      cleanup_temp_dir(temp_dir)
    end
  end

  # mrblib ディレクトリから .rb ファイルを再帰的に収集
  def self.collect_rb_files(downloader, base_path, items, prefix = "")
    rb_files = []

    items.each do |item|
      name = item["name"]
      type = item["type"]
      path = item["path"]

      if type == "file" && name.end_with?(".rb")
        display_name = prefix.empty? ? name : "#{prefix}/#{name}"
        rb_files << { name: display_name, path: path }
      elsif type == "dir"
        # サブディレクトリを再帰的に探索
        sub_items = downloader.list_directory(path)
        if sub_items
          sub_prefix = prefix.empty? ? name : "#{prefix}/#{name}"
          rb_files.concat(collect_rb_files(downloader, path, sub_items, sub_prefix))
        end
      end
    end

    rb_files
  end

  # 一時ディレクトリを削除
  def self.cleanup_temp_dir(dir)
    return unless File.exist?(dir)

    # ディレクトリ内のファイルを削除
    Dir.entries(dir).each do |entry|
      next if entry == "." || entry == ".."
      path = "#{dir}/#{entry}"
      if File.directory?(path)
        cleanup_temp_dir(path)
      else
        File.delete(path)
      end
    end
    Dir.rmdir(dir)
  rescue
    # 削除に失敗しても続行
  end

  # --repo URL をパースして owner/repo を設定
  def self.parse_repo_url(opts)
    url = opts[:repo_url]

    if url.start_with?("https://github.com/")
      path = url.sub("https://github.com/", "")
      # 末尾の .git を除去
      if path.end_with?(".git")
        path = path[0, path.length - 4]
      end
      parts = path.split("/")
      if parts.length >= 2
        opts[:owner] = parts[0]
        opts[:repo] = parts[1]
        return
      end
    elsif url.include?("/") && !url.include?("://")
      # owner/repo 形式
      parts = url.split("/")
      if parts.length == 2
        opts[:owner] = parts[0]
        opts[:repo] = parts[1]
        return
      end
    end

    puts "Error: Invalid repository URL or format"
    puts "Expected format: https://github.com/owner/repo or owner/repo"
    exit 1
  end

  def self.parse_add_options(args)
    opts = {
      gem_name: nil,
      repo_url: nil,
      branch: nil,
      output: "lib"
    }

    i = 0
    positional = []

    while i < args.length
      arg = args[i]

      case arg
      when "-r", "--repo"
        i += 1
        opts[:repo_url] = args[i]
      when "-b", "--branch"
        i += 1
        opts[:branch] = args[i]
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

    # 位置引数があれば gem 名として扱う
    opts[:gem_name] = positional[0] if positional.length > 0

    opts
  end

  def self.print_add_usage
    puts "Usage: picogem add <gem-name> [options]"
    puts "       picogem add --repo <github-url> [options]"
    puts ""
    puts "Download and compile a mrbgem from GitHub."
    puts ""
    puts "Modes:"
    puts "  <gem-name>             Download from picoruby/picoruby repository"
    puts "                         (branch: master, path: mrbgems/<gem-name>/mrblib)"
    puts "  --repo <url>           Download from specified repository"
    puts "                         (branch: main, path: mrblib)"
    puts ""
    puts "Options:"
    puts "  -r, --repo URL         GitHub repository URL or owner/repo"
    puts "  -b, --branch BRANCH    Branch name (default: master for picoruby, main for --repo)"
    puts "  -o, --output DIR       Output directory for compiled .mrb files (default: lib)"
    puts "  -h, --help             Show this help"
    puts ""
    puts "Examples:"
    puts "  picogem add picoruby-aht25"
    puts "  picogem add --repo https://github.com/ksbmyk/picoruby-ws2812"
  end
end
