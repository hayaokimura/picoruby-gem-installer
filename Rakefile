# picoruby-gem-installer Rakefile

require 'fileutils'

# ディレクトリ設定
MRUBY_DIR     = 'mruby'
BUILD_DIR     = 'build'
MRUBY_CONFIG  = File.expand_path('build_config.rb', __dir__)

# mrubyのビルド成果物
MRUBY_LIB     = "#{MRUBY_DIR}/build/host/lib/libmruby.a"
MRUBY_INC     = "#{MRUBY_DIR}/include"
MRBC          = "#{MRUBY_DIR}/build/host/bin/mrbc"

# ソースファイル
RUBY_SRC      = 'mrblib/downloader.rb'
C_SRC         = 'src/main.c'
BYTECODE_C    = "#{BUILD_DIR}/app_bytecode.c"

# バイナリ名
BINARY_NAME   = 'picogem'

# 出力ディレクトリ
DIR_LINUX          = "#{BUILD_DIR}/linux"
DIR_MACOS_X86      = "#{BUILD_DIR}/darwin-x86_64"
DIR_MACOS_ARM      = "#{BUILD_DIR}/darwin-arm64"

# 出力バイナリ
TARGET            = "#{DIR_LINUX}/#{BINARY_NAME}"
TARGET_MACOS_X86  = "#{DIR_MACOS_X86}/#{BINARY_NAME}"
TARGET_MACOS_ARM  = "#{DIR_MACOS_ARM}/#{BINARY_NAME}"

# コンパイラ設定
CC       = ENV['CC'] || 'gcc'
CFLAGS   = "-std=c99 -O2 -Wall -I#{MRUBY_INC} -I#{BUILD_DIR}"
LIBS     = '-lcurl -lssl -lcrypto -lz -lpthread -lm -ldl'

# osxcross設定
DARWIN_VERSION = ENV['DARWIN_VERSION'] || '20'

# ============================
# デフォルトタスク
# ============================
task default: :linux

desc 'Show available tasks'
task :help do
  puts <<~HELP
    Usage: rake [task]

    Tasks:
      rake              - Build Linux binary (default)
      rake linux        - Build Linux binary
      rake macos        - Build macOS binaries (requires osxcross)
      rake all          - Build for all platforms
      rake test         - Run basic test
      rake clean        - Clean build artifacts
      rake clean_all    - Clean all (including mruby build)
  HELP
end

# ============================
# ディレクトリ作成
# ============================
directory BUILD_DIR
directory DIR_LINUX
directory DIR_MACOS_X86
directory DIR_MACOS_ARM

# ============================
# mruby ビルド
# ============================
desc 'Build mruby'
task :mruby => MRUBY_LIB

file MRUBY_LIB => MRUBY_CONFIG do
  puts "=== Building mruby ==="
  Dir.chdir(MRUBY_DIR) do
    sh "MRUBY_CONFIG=#{MRUBY_CONFIG} rake"
  end
end

file MRBC => MRUBY_LIB

# ============================
# バイトコード生成
# ============================
file BYTECODE_C => [RUBY_SRC, MRBC, BUILD_DIR] do
  puts "=== Compiling Ruby to bytecode ==="
  sh "#{MRBC} -Bapp_bytecode -o #{BYTECODE_C} #{RUBY_SRC}"
end

# ============================
# Linux バイナリ
# ============================
desc 'Build Linux binary'
task linux: TARGET

file TARGET => [C_SRC, BYTECODE_C, MRUBY_LIB, DIR_LINUX] do
  puts "=== Building Linux binary ==="
  sh "#{CC} #{CFLAGS} -o #{TARGET} #{C_SRC} #{MRUBY_LIB} #{LIBS}"
  puts "Built: #{TARGET}"
  sh "ls -lh #{TARGET}"
end

# ============================
# macOS ビルド用ヘルパー
# ============================
def build_mruby_cross
  return if Dir.exist?("#{MRUBY_DIR}/build/x86_64-apple-darwin")
  
  puts "=== Building mruby for macOS (cross-compile) ==="
  Dir.chdir(MRUBY_DIR) do
    sh "MRUBY_CONFIG=#{MRUBY_CONFIG} CROSS_MACOS=1 rake"
  end
end

def osxcross_clang(arch)
  "#{arch}-apple-darwin#{DARWIN_VERSION}-clang"
end

def osxcross_ar(arch)
  "#{arch}-apple-darwin#{DARWIN_VERSION}-ar"
end

# ============================
# macOS x86_64 バイナリ
# ============================
file TARGET_MACOS_X86 => [C_SRC, BYTECODE_C, DIR_MACOS_X86] do
  build_mruby_cross
  
  puts "=== Building macOS x86_64 binary ==="
  mruby_lib_macos = "#{MRUBY_DIR}/build/x86_64-apple-darwin/lib/libmruby.a"
  
  sh <<~CMD.gsub("\n", " ")
    #{osxcross_clang('x86_64')}
    -std=c99 -O2 -Wall
    -I#{MRUBY_INC} -I#{BUILD_DIR}
    -mmacosx-version-min=10.13
    -o #{TARGET_MACOS_X86}
    #{C_SRC}
    #{mruby_lib_macos}
    -lcurl -lz
  CMD
  
  puts "Built: #{TARGET_MACOS_X86}"
end

# ============================
# macOS arm64 バイナリ
# ============================
file TARGET_MACOS_ARM => [C_SRC, BYTECODE_C, DIR_MACOS_ARM] do
  build_mruby_cross
  
  puts "=== Building macOS arm64 binary ==="
  mruby_lib_macos = "#{MRUBY_DIR}/build/arm64-apple-darwin/lib/libmruby.a"
  
  sh <<~CMD.gsub("\n", " ")
    #{osxcross_clang('arm64')}
    -std=c99 -O2 -Wall
    -I#{MRUBY_INC} -I#{BUILD_DIR}
    -mmacosx-version-min=11.0
    -arch arm64
    -o #{TARGET_MACOS_ARM}
    #{C_SRC}
    #{mruby_lib_macos}
    -lcurl -lz
  CMD
  
  puts "Built: #{TARGET_MACOS_ARM}"
end

# ============================
# macOS バイナリ（両アーキテクチャ）
# ============================
desc 'Build macOS binaries (requires osxcross)'
task macos: [TARGET_MACOS_X86, TARGET_MACOS_ARM]

# ============================
# 全プラットフォーム
# ============================
desc 'Build for all platforms'
task all: [:linux, :macos]

# ============================
# テスト
# ============================
desc 'Run basic test'
task test: :linux do
  puts "=== Running test ==="
  sh "#{TARGET} --help"
end

# ============================
# クリーンアップ
# ============================
desc 'Clean build artifacts'
task :clean do
  puts "=== Cleaning build directory ==="
  FileUtils.rm_rf(BUILD_DIR)
  puts "Cleaned: #{BUILD_DIR}"
end

desc 'Clean all (including mruby build)'
task clean_all: :clean do
  puts "=== Cleaning mruby build ==="
  Dir.chdir(MRUBY_DIR) do
    sh "rake deep_clean"
  end if Dir.exist?(MRUBY_DIR)
end
