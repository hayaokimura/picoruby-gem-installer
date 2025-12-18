# Commands::sync - Sync local Ruby files to storage
module Commands
  # sync コマンド - ローカルの .rb ファイルをストレージにコピー
  def self.sync(args)
    opts = parse_sync_options(args)

    if opts[:storage].nil?
      print_sync_usage
      exit 1
    end

    storage = opts[:storage]

    puts "=== picogem sync ==="
    puts "Storage: #{storage}"
    puts ""

    # コピー先ディレクトリを作成
    home_dir = "#{storage}/home"
    lib_dir = "#{storage}/lib"

    mkdir_p(home_dir)
    mkdir_p(lib_dir)

    # カレントディレクトリの *.rb ファイルを home にコピー
    puts "Copying *.rb files to #{home_dir}..."
    copy_rb_files(".", home_dir, false)

    # lib 以下の *.rb ファイルを lib にコピー
    if File.exist?("lib") && File.directory?("lib")
      puts "Copying lib/**/*.rb files to #{lib_dir}..."
      copy_rb_files_recursive("lib", lib_dir)
    else
      puts "No lib directory found, skipping lib copy."
    end

    puts ""
    puts "Sync completed!"

    # watch モードの場合、ファイル監視を開始
    if opts[:watch]
      watch_files(storage, home_dir, lib_dir)
    end
  end

  # ファイル監視モード
  def self.watch_files(storage, home_dir, lib_dir)
    puts ""
    puts "Watching for file changes... (Press Ctrl+C to stop)"
    puts ""

    # 監視対象ファイルの mtime を記録
    file_mtimes = collect_file_mtimes

    loop do
      IO.select(nil, nil, nil, 1)  # 1秒待機

      # 現在のファイルの mtime を取得
      current_mtimes = collect_file_mtimes

      # 変更されたファイルを検出
      changed_files = []

      current_mtimes.each do |path, mtime|
        if file_mtimes[path].nil?
          # 新規ファイル
          changed_files << { path: path, type: :new }
        elsif file_mtimes[path] != mtime
          # 更新されたファイル
          changed_files << { path: path, type: :modified }
        end
      end

      # 削除されたファイルを検出
      file_mtimes.each do |path, _|
        unless current_mtimes.key?(path)
          changed_files << { path: path, type: :deleted }
        end
      end

      # 変更があればコピー
      changed_files.each do |change|
        path = change[:path]
        type = change[:type]

        case type
        when :new, :modified
          dest_path = get_dest_path(path, home_dir, lib_dir)
          if dest_path
            # コピー先ディレクトリを作成
            dest_dir = File.dirname(dest_path)
            mkdir_p(dest_dir)
            copy_file(path, dest_path)
            puts "  [#{type == :new ? 'NEW' : 'MODIFIED'}] #{path}"
          end
        when :deleted
          puts "  [DELETED] #{path} (manual cleanup may be needed)"
        end
      end

      # mtime を更新
      file_mtimes = current_mtimes
    end
  end

  # ファイルの mtime を取得
  def self.get_file_mtime(path)
    File.open(path, 'rb') { |f| f.mtime }
  end

  # 監視対象ファイルの mtime を収集
  def self.collect_file_mtimes
    mtimes = {}

    # カレントディレクトリの .rb ファイル
    Dir.entries(".").each do |entry|
      next if entry == "." || entry == ".."
      next if entry == "lib"  # lib は別途処理
      path = "./#{entry}"
      if File.file?(path) && entry.end_with?(".rb")
        mtimes[path] = get_file_mtime(path)
      end
    end

    # lib 以下の .rb/.mrb ファイル
    if File.exist?("lib") && File.directory?("lib")
      collect_file_mtimes_recursive("lib", mtimes)
    end

    mtimes
  end

  # 再帰的に mtime を収集
  def self.collect_file_mtimes_recursive(dir, mtimes)
    Dir.entries(dir).each do |entry|
      next if entry == "." || entry == ".."
      path = "#{dir}/#{entry}"

      if File.directory?(path)
        collect_file_mtimes_recursive(path, mtimes)
      elsif File.file?(path) && (entry.end_with?(".rb") || entry.end_with?(".mrb"))
        mtimes[path] = get_file_mtime(path)
      end
    end
  end

  # コピー先パスを取得
  def self.get_dest_path(src_path, home_dir, lib_dir)
    if src_path.start_with?("./")
      # カレントディレクトリのファイル -> home へ
      filename = File.basename(src_path)
      "#{home_dir}/#{filename}"
    elsif src_path.start_with?("lib/")
      # lib 以下のファイル -> lib へ（サブディレクトリ構造を維持）
      relative_path = src_path[4..-1]  # "lib/" を除去
      "#{lib_dir}/#{relative_path}"
    else
      nil
    end
  end

  def self.parse_sync_options(args)
    opts = {
      storage: nil,
      watch: false
    }

    i = 0
    positional = []

    while i < args.length
      arg = args[i]

      case arg
      when "-h", "--help"
        print_sync_usage
        exit 0
      when "-w", "--watch"
        opts[:watch] = true
      else
        positional << arg unless arg.start_with?("-")
      end

      i += 1
    end

    opts[:storage] = positional[0] if positional.length > 0

    opts
  end

  def self.print_sync_usage
    puts "Usage: picogem sync [options] <storage_directory>"
    puts ""
    puts "Sync local Ruby files to storage:"
    puts "  - Copy *.rb files from current directory to <storage>/home"
    puts "  - Copy lib/**/*.rb and lib/**/*.mrb files to <storage>/lib"
    puts ""
    puts "Options:"
    puts "  -w, --watch            Watch for file changes and auto-sync"
    puts "  -h, --help             Show this help"
    puts ""
    puts "Example:"
    puts "  picogem sync /mnt/pico"
    puts "  picogem sync /media/user/RPI-RP2"
    puts "  picogem sync --watch /mnt/pico"
  end
end
