require "../Interpreter/InterpreterBridge"
require "../Tools/Logger"
require "./ReplReader"
require "./ResultRenderer"


module REPLica


  # The interactive shell read-eval-print loop
  module FShell

    extend self

    enum ECommand
      Skip #<< blank line, ignore
      Exit #<< leave the session
      Help #<< show meta-command help
      Eval #<< evaluate as Crystal source
    end

    META_COMMANDS = {
      "exit"  => "leave the session",
      "quit"  => "leave the session",
      ":help" => "show this help",
    }

    #--------------------------------------------------------------------------

    # Boots the interpreter and runs the loop until the user exits/EOF
    #
    # `bootstrap_path` is the host project directory or specific file path
    # its `lib/` is added to the search path so the project's shards resolve
    def run ( bootstrap_path : String ) : Nil
      joined_lib    = get_joined_lib( bootstrap_path )

      FLog.info ( "Found #{joined_lib}")

      bridge        = boot( joined_lib )
      reader        = FReplReader.new( bridge )
      reader.color  = colored?

      greet
      load_if_file( bridge, bootstrap_path )
      loop_until_exit( bridge, reader )
      farewell
    end

    #--------------------------------------------------------------------------

    def classify ( expression : String ) : ECommand
      case expression.strip
      when ""             then ECommand::Skip
      when "exit", "quit" then ECommand::Exit
      when ":help"        then ECommand::Help
      else                     ECommand::Eval
      end
    end

    #--------------------------------------------------------------------------

    private def boot ( project_libs : String ) : FInterpreterBridge
      FLog.step( "Starting REPLica session..." )
      bridge = FInterpreterBridge.new( project_libs )
      FLog.ok( "Interpreter ready." )
      bridge
    end

    private def loop_until_exit ( bridge : FInterpreterBridge, reader : FReplReader ) : Nil
      reader.read_loop do |expression|
        case classify( expression )
        when .skip?
          next
        when .exit?
          break
        when .help?
          print_help
        when .eval?
          FResultRenderer.render( bridge.eval( expression ) )
        end
      end
    end

    #--------------------------------------------------------------------------

    private def greet : Nil
      FLog.info( "REPLica — interactive Crystal console. Type :help for commands, exit to quit." )
    end

    private def farewell : Nil
      FLog.info( "" )
      FLog.step( "Session ended." )
    end

    private def print_help : Nil
      META_COMMANDS.each { |name, description| FLog.info( "  #{name}\t#{description}" ) }
    end

    private def colored? : Bool
      STDOUT.tty?
    end

    private def get_joined_lib( bootstrap_path : String ) : String
      project_libs = [] of String
      project_libs << File.expand_path( "lib" )
      project_root = find_project_root( bootstrap_path )
      project_libs << File.join( project_root, "lib" )
      project_libs.uniq.join( FCrystalEnv::PATH_DELIMITER )
    end

    private def load_if_file( bridge : FInterpreterBridge, bootstrap_path : String ) : Nil
      if File.file?( bootstrap_path )
        FLog.step( "Loading #{bootstrap_path}..." )
        relative_path = get_crystal_require_path_format( bootstrap_path )
        outcome = bridge.eval( %(require "#{relative_path}") )
        if outcome.ok?
          FLog.ok( "Loaded #{bootstrap_path}." )
        else
          FLog.error( "Failed to load #{bootstrap_path}:\n#{outcome.error}" )
        end
      end
    end

    private def get_crystal_require_path_format( bootstrap_path : String ) : String
      absolute_path = File.expand_path( bootstrap_path )
      relative_path = Path[absolute_path].relative_to( Dir.current ).to_s
      relative_path = "./" + relative_path unless relative_path.starts_with?( '.' )
      relative_path
    end

    private def find_project_root( path : String ) : String
      current = File.expand_path( path )
      current = File.dirname( current ) unless File.directory?( current )

      while current != "/"
        if Dir.exists?( File.join( current, "lib" ) ) || File.exists?( File.join( current, "shard.yml" ) )
          return current
        end
        parent = File.dirname( current )
        break if parent == current
        current = parent
      end
      File.directory?( path ) ? path : File.dirname( path )
    end

  end


end
