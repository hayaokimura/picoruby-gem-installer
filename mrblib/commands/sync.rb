# Commands::sync - Sync local Ruby files to storage
module Commands
  # sync command - Copy local .rb files to storage
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

    # Create destination directories
    home_dir = "#{storage}/home"
    lib_dir = "#{storage}/lib"

    mkdir_p(home_dir)
    mkdir_p(lib_dir)

    # Sync all files
    sync_all_files(home_dir, lib_dir)

    puts ""
    puts "Sync completed!"

    # Start file watching if watch mode is enabled
    if opts[:watch]
      watch_files(home_dir, lib_dir)
    end
  end

  # ========================================
  # Common methods
  # ========================================

  # Collect list of files to sync
  def self.collect_sync_files
    files = []

    # .rb files in current directory
    Dir.entries(".").each do |entry|
      next if entry == "." || entry == ".."
      next if entry == "lib"  # lib is processed separately
      path = "./#{entry}"
      if File.file?(path) && entry.end_with?(".rb")
        files << path
      end
    end

    # .rb/.mrb files under lib directory
    if File.exist?("lib") && File.directory?("lib")
      collect_sync_files_recursive("lib", files)
    end

    files
  end

  # Recursively collect file list
  def self.collect_sync_files_recursive(dir, files)
    Dir.entries(dir).each do |entry|
      next if entry == "." || entry == ".."
      path = "#{dir}/#{entry}"

      if File.directory?(path)
        collect_sync_files_recursive(path, files)
      elsif File.file?(path) && (entry.end_with?(".rb") || entry.end_with?(".mrb"))
        files << path
      end
    end
  end

  # Get destination path for a source file
  def self.get_dest_path(src_path, home_dir, lib_dir)
    if src_path.start_with?("./")
      # Files in current directory -> home
      filename = File.basename(src_path)
      "#{home_dir}/#{filename}"
    elsif src_path.start_with?("lib/")
      # Files under lib -> lib (preserving subdirectory structure)
      relative_path = src_path[4..-1]  # Remove "lib/" prefix
      "#{lib_dir}/#{relative_path}"
    else
      nil
    end
  end

  # Sync a single file
  def self.sync_single_file(src_path, home_dir, lib_dir)
    dest_path = get_dest_path(src_path, home_dir, lib_dir)
    return unless dest_path

    # Create destination directory
    dest_dir = File.dirname(dest_path)
    mkdir_p(dest_dir)

    copy_file(src_path, dest_path)
  end

  # Sync all files
  def self.sync_all_files(home_dir, lib_dir)
    files = collect_sync_files
    files.each { |path| sync_single_file(path, home_dir, lib_dir) }
    puts "  Copied #{files.length} file(s)"
  end

  # ========================================
  # Watch mode
  # ========================================

  # File watching mode
  def self.watch_files(home_dir, lib_dir)
    puts ""
    puts "Watching for file changes... (Press Ctrl+C to stop)"
    puts ""

    # Record mtime of watched files
    file_mtimes = collect_file_mtimes

    loop do
      IO.select(nil, nil, nil, 1)  # Wait 1 second

      # Get current mtime of files
      current_mtimes = collect_file_mtimes

      # Detect changed files
      changed_files = []

      current_mtimes.each do |path, mtime|
        if file_mtimes[path].nil?
          # New file
          changed_files << { path: path, type: :new }
        elsif file_mtimes[path] != mtime
          # Modified file
          changed_files << { path: path, type: :modified }
        end
      end

      # Detect deleted files
      file_mtimes.each do |path, _|
        unless current_mtimes.key?(path)
          changed_files << { path: path, type: :deleted }
        end
      end

      # Copy if there are changes
      changed_files.each do |change|
        path = change[:path]
        type = change[:type]

        case type
        when :new, :modified
          sync_single_file(path, home_dir, lib_dir)
          puts "  [#{type == :new ? 'NEW' : 'MODIFIED'}] #{path}"
        when :deleted
          puts "  [DELETED] #{path} (manual cleanup may be needed)"
        end
      end

      # Update mtime records
      file_mtimes = current_mtimes
    end
  end

  # Get mtime of a file
  def self.get_file_mtime(path)
    File.open(path, 'rb') { |f| f.mtime }
  end

  # Collect mtime of watched files
  def self.collect_file_mtimes
    mtimes = {}
    collect_sync_files.each do |path|
      mtimes[path] = get_file_mtime(path)
    end
    mtimes
  end

  # ========================================
  # Option parser
  # ========================================

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
