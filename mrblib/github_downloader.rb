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
    headers = {
      'User-Agent' => 'picogem/1.0',
      'Accept' => 'application/vnd.github.v3+json'
    }

    # GITHUB_TOKEN が設定されている場合は認証ヘッダーを追加
    github_token = ENV['GITHUB_TOKEN']
    if github_token && !github_token.empty?
      headers['Authorization'] = "Bearer #{github_token}"
    end

    headers
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
