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
  end

  def self.parse_sync_options(args)
    opts = {
      storage: nil
    }

    i = 0
    positional = []

    while i < args.length
      arg = args[i]

      case arg
      when "-h", "--help"
        print_sync_usage
        exit 0
      else
        positional << arg unless arg.start_with?("-")
      end

      i += 1
    end

    opts[:storage] = positional[0] if positional.length > 0

    opts
  end

  def self.print_sync_usage
    puts "Usage: picogem sync <storage_directory>"
    puts ""
    puts "Sync local Ruby files to storage:"
    puts "  - Copy *.rb files from current directory to <storage>/home"
    puts "  - Copy lib/**/*.rb and lib/**/*.mrb files to <storage>/lib"
    puts ""
    puts "Options:"
    puts "  -h, --help             Show this help"
    puts ""
    puts "Example:"
    puts "  picogem sync /mnt/pico"
    puts "  picogem sync /media/user/RPI-RP2"
  end
end
