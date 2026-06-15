require "../Interpreter/InterpreterBridge"
require "../Completion/CompletionEngine"


module REPLica


  # Subclasses the Crystal compiler's own `Crystal::ReplReader`
  class FReplReader < Crystal::ReplReader

    HISTORY_FILE_NAME = ".replica_history"
    HISTORY_FILE_PERM = 0o600

    @bridge : FInterpreterBridge

    #--------------------------------------------------------------------------

    # `bridge` is the interpreter wrapper: its `repl` provides the parser context the
    # inherited hooks need (multi-line detection, highlighting), and the
    # `auto_complete` override queries it for type-aware completion.
    def initialize ( @bridge : FInterpreterBridge )
      super( @bridge.repl )
    end

    #--------------------------------------------------------------------------

    def prompt ( io : IO, line_number : Int32, color : Bool ) : Nil
      io << "replica:"
      io << sprintf( "%03d", line_number )
      io << ( @incomplete ? '*' : '>' )
      io << ' '
    end

    #--------------------------------------------------------------------------

    # Type-aware completion: delegate to the engine, falling back to the inherited completion
    def auto_complete ( name_filter : String, expression : String ) : {String, Array(String)}
      FCompletionEngine.complete( @bridge, name_filter, expression ) || super
    end

    #--------------------------------------------------------------------------

    # Persist history under the user's home directory
    # `nil` disables persistence (and, upstream, reverse i-search) when no home is resolvable.
    def history_file : String?
      home = ENV["HOME"]?
      return nil if home.nil? || home.empty?

      path = File.join( home, HISTORY_FILE_NAME )
      secure_history_file( path )
      path
    end

    #--------------------------------------------------------------------------

    # Ensures the history file exists with private permissions before the reader writes to it
    private def secure_history_file ( path : String ) : Nil
      if File.exists?( path )
        File.chmod( path, HISTORY_FILE_PERM )
      else
        File.open( path, "w", perm: File::Permissions.new( HISTORY_FILE_PERM ) ) { }
      end
    rescue ex : File::Error | IO::Error
      # Non-fatal: history may simply not persist this session.
    end

  end


end
