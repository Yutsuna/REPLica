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
    # `bootstrap_path` is the host project directory
    # its `lib/` is added to the search path so the project's shards resolve
    def run ( bootstrap_path : String ) : Nil
      bridge = boot( bootstrap_path )
      reader = FReplReader.new( bridge )
      reader.color = colored?

      greet
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

    private def boot ( bootstrap_path : String ) : FInterpreterBridge
      FLog.step( "Starting REPLica session..." )
      bridge = FInterpreterBridge.new( File.join( bootstrap_path, "lib" ) )
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

  end


end
