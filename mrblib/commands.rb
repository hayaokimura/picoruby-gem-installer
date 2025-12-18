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
end
