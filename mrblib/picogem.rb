# picogem - PicoRuby Gem Manager
# Main entry point

def print_usage
  puts "Usage: picogem <command> [options]"
  puts ""
  puts "Commands:"
  puts "  add <package>    Download a PicoRuby gem"
  puts "  list             List available runtime gems"
  puts "  sync <storage>   Sync local .rb files to storage"
  puts ""
  puts "Options:"
  puts "  -h, --help       Show this help"
  puts "  -v, --version    Show version"
  puts ""
  puts "Example:"
  puts "  picogem add picoruby-mcp3424"
  puts "  picogem list"
  puts "  picogem sync /mnt/pico"
  puts ""
  puts "Run 'picogem <command> --help' for more information on a command."
end

def print_version
  puts "picogem version 1.0.0"
end

# メイン実行
if __FILE__ == $PROGRAM_NAME || ARGV.length > 0
  if ARGV.length == 0
    print_usage
    exit 1
  end

  command = ARGV[0]
  args = ARGV[1..-1] || []

  case command
  when "add"
    Commands.add(args)
  when "list"
    Commands.list(args)
  when "sync"
    Commands.sync(args)
  when "-h", "--help"
    print_usage
    exit 0
  when "-v", "--version"
    print_version
    exit 0
  else
    puts "Error: Unknown command '#{command}'"
    puts ""
    print_usage
    exit 1
  end
end
