# picoruby-gem-installer build configuration

def gem_config(conf)
  # 標準ライブラリ
  conf.gembox 'default'

  # ファイルI/O
  conf.gem core: 'mruby-io'

  # exit関数
  conf.gem core: 'mruby-exit'

  # HTTP/HTTPS通信（libcurl使用）
  conf.gem github: 'mattn/mruby-curl'

  # JSON解析（GitHub API用）
  conf.gem github: 'mattn/mruby-json'

  # コマンドライン引数
  conf.gem core: 'mruby-bin-mruby'
end

# ============================
# Linux ネイティブビルド
# ============================
MRuby::Build.new do |conf|
  toolchain :gcc

  conf.cc.flags << '-DCURL_STATICLIB'

  # 静的リンク（配布用）
  # conf.cc.flags << '-static'
  # conf.linker.flags << '-static'

  conf.linker.libraries << %w[curl ssl crypto z pthread m]

  gem_config(conf)

  # バイナリ生成用ツール
  conf.gem core: 'mruby-bin-mrbc'
end

# ============================
# macOS x86_64 クロスビルド（osxcross使用）
# ============================
MRuby::CrossBuild.new('x86_64-apple-darwin') do |conf|
  toolchain :clang

  # osxcrossのツールチェーン
  # 環境に合わせてdarwinバージョンを調整
  DARWIN_VERSION = ENV['DARWIN_VERSION'] || 'darwin20'
  OSXCROSS_TARGET = "x86_64-apple-#{DARWIN_VERSION}"

  conf.cc.command = "#{OSXCROSS_TARGET}-clang"
  conf.cc.flags << '-mmacosx-version-min=10.13'

  conf.cxx.command = "#{OSXCROSS_TARGET}-clang++"
  conf.cxx.flags << '-mmacosx-version-min=10.13'
  conf.cxx.flags << '-stdlib=libc++'

  conf.linker.command = "#{OSXCROSS_TARGET}-clang"
  conf.linker.flags << '-mmacosx-version-min=10.13'

  conf.archiver.command = "#{OSXCROSS_TARGET}-ar"

  # macOS用依存ライブラリのパス（事前にクロスビルドが必要）
  macos_deps = ENV['MACOS_DEPS'] || '/opt/osxcross-deps'
  if Dir.exist?(macos_deps)
    conf.cc.include_paths << "#{macos_deps}/include"
    conf.linker.library_paths << "#{macos_deps}/lib"
  end

  conf.linker.libraries << %w[curl z]

  conf.host_target = OSXCROSS_TARGET
  conf.build_target = 'x86_64-pc-linux-gnu'

  conf.build_mrbtest_lib_only
  gem_config(conf)
end if ENV['CROSS_MACOS']

# ============================
# macOS arm64 クロスビルド（osxcross使用）
# ============================
MRuby::CrossBuild.new('arm64-apple-darwin') do |conf|
  toolchain :clang

  DARWIN_VERSION = ENV['DARWIN_VERSION'] || 'darwin20'
  OSXCROSS_TARGET = "arm64-apple-#{DARWIN_VERSION}"

  conf.cc.command = "#{OSXCROSS_TARGET}-clang"
  conf.cc.flags << '-mmacosx-version-min=11.0'
  conf.cc.flags << '-arch arm64'

  conf.cxx.command = "#{OSXCROSS_TARGET}-clang++"
  conf.cxx.flags << '-mmacosx-version-min=11.0'
  conf.cxx.flags << '-arch arm64'
  conf.cxx.flags << '-stdlib=libc++'

  conf.linker.command = "#{OSXCROSS_TARGET}-clang"
  conf.linker.flags << '-mmacosx-version-min=11.0'
  conf.linker.flags << '-arch arm64'

  conf.archiver.command = "#{OSXCROSS_TARGET}-ar"

  macos_deps = ENV['MACOS_DEPS_ARM64'] || '/opt/osxcross-deps-arm64'
  if Dir.exist?(macos_deps)
    conf.cc.include_paths << "#{macos_deps}/include"
    conf.linker.library_paths << "#{macos_deps}/lib"
  end

  conf.linker.libraries << %w[curl z]

  conf.host_target = OSXCROSS_TARGET
  conf.build_target = 'x86_64-pc-linux-gnu'

  conf.build_mrbtest_lib_only
  gem_config(conf)
end if ENV['CROSS_MACOS']
