# Commands module - common utilities
module Commands
  # ディレクトリを再帰的に作成
  def self.mkdir_p(path)
    parts = path.split('/')
    current = ""
    parts.each do |part|
      next if part.empty?
      current = current.empty? ? part : "#{current}/#{part}"
      # 絶対パスの場合は先頭の / を追加
      current = "/#{current}" if path.start_with?("/") && !current.start_with?("/")
      Dir.mkdir(current) unless File.exist?(current)
    end
  end

  # ファイルをコピー
  def self.copy_file(src, dest)
    content = File.open(src, 'rb') { |f| f.read }
    File.open(dest, 'wb') { |f| f.write(content) }
    puts "    #{src} -> #{dest}"
  end

  # ディレクトリの .rb ファイルをコピー（非再帰）
  def self.copy_rb_files(src_dir, dest_dir, recursive = false)
    count = 0
    Dir.entries(src_dir).each do |entry|
      next if entry == "." || entry == ".."

      src_path = "#{src_dir}/#{entry}"

      if File.file?(src_path) && entry.end_with?(".rb")
        dest_path = "#{dest_dir}/#{entry}"
        copy_file(src_path, dest_path)
        count += 1
      end
    end
    puts "  Copied #{count} file(s)"
    count
  end

  # ディレクトリの .rb ファイルを再帰的にコピー
  def self.copy_rb_files_recursive(src_dir, dest_dir)
    total_count = 0
    copy_rb_files_recursive_impl(src_dir, dest_dir, total_count)
  end

  def self.copy_rb_files_recursive_impl(src_dir, dest_dir, count)
    Dir.entries(src_dir).each do |entry|
      next if entry == "." || entry == ".."

      src_path = "#{src_dir}/#{entry}"
      dest_path = "#{dest_dir}/#{entry}"

      if File.directory?(src_path)
        mkdir_p(dest_path)
        copy_rb_files_recursive_impl(src_path, dest_path, count)
      elsif File.file?(src_path) && (entry.end_with?(".rb") || entry.end_with?(".mrb"))
        copy_file(src_path, dest_path)
        count += 1
      end
    end
    puts "  Copied files from #{src_dir}"
    count
  end
end
