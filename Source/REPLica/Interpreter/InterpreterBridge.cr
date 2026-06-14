require "./CrystalPatches"
require "./Errors"
require "./CrystalEnv"
require "../Tools/Logger"


module REPLica


  # Outcome of evaluating one piece of source in the interpreter.
  #
  # `value`     -> display the result of the evaluation
  # `nil`       -> no value was produced
  # `error`     -> display the error message
  # `warnings`  -> display any non-fatal warnings
  struct FEvalOutcome

    getter value : String?
    getter error : String?
    getter warnings : String?

    def initialize ( @value : String? = nil, @error : String? = nil, @warnings : String? = nil )
    end

    def ok? : Bool
      @error.nil?
    end

    def has_value? : Bool
      !@value.nil?
    end

    def has_warnings? : Bool
      !@warnings.nil?
    end

  end


  # Crash-safe wrapper around the in-process Crystal interpreter.
  #
  # NOTE: a process can host exactly ONE `Crystal::Repl` instance.
  # A second one corrupts it.
  # The single interpreter is held in the class-level `@@interpreter` and shared by every wrapper
  class FInterpreterBridge

    @@interpreter : Crystal::Repl? = nil

    #--------------------------------------------------------------------------

    # Builds the @@interpreter and loads the prelude.
    def initialize ( project_lib : String? = nil )
      if @@interpreter
        FLog.warn( "interpreter already initialized; ignoring project_lib=#{project_lib}" ) if project_lib
        return
      end

      FCrystalEnv.configure( project_lib )
      repl = Crystal::Repl.new
      load_prelude( repl )
      @@interpreter = repl
    end

    #--------------------------------------------------------------------------

    # Evaluates *source* in the persistent session and returns its outcome.
    def eval ( source : String ) : FEvalOutcome
      return FEvalOutcome.new if source.blank?

      result = interpreter.parse_and_interpret( source )
      FEvalOutcome.new( value: result.value.try( &.to_s ), warnings: collect_warnings( result.warnings ) )
    rescue ex : Crystal::Repl::EscapingException
      FEvalOutcome.new( error: describe( ex ) )
    rescue ex : Crystal::CodeError
      FEvalOutcome.new( error: describe( ex ) )
    rescue ex : Exception
      FEvalOutcome.new( error: describe( ex ) )
    end

    #--------------------------------------------------------------------------

    # The live semantic program, used by the completion engine to resolve types.
    def program : Crystal::Program
      interpreter.program
    end

    def repl : Crystal::Repl
      interpreter
    end

    # Compile-time type of a top-level local variable, or `nil` if unknown.
    def local_var_type ( name : String ) : Crystal::Type?
      interpreter.interpreter.local_vars.type?( name, 0 )
    rescue ex
      FLog.warn( "local_var_type(#{name}) failed: #{ex.message}" )
      nil
    end

    # Names of the local variables currently in scope at the top level.
    def local_var_names : Array(String)
      interpreter.interpreter.local_vars.names_at_block_level_zero.to_a
    rescue ex
      FLog.warn( "local_var_names failed: #{ex.message}" )
      [] of String
    end

    # Instance type of an arbitrary receiver expression
    # resolved by the compiler without executing user code, or `nil` when unresolvable.
    def infer_type ( receiver : String ) : Crystal::Type?
      return nil if receiver.blank?

      interpreter.infer_type( receiver )
    rescue ex
      FLog.warn( "infer_type(#{receiver}) failed: #{ex.message}" )
      nil
    end

    # The top-level type/constant named *name* (e.g. `User`), or `nil` if there is none.
    def top_level_type ( name : String ) : Crystal::Type?
      interpreter.program.types[name]?
    rescue ex
      FLog.warn( "top_level_type(#{name}) failed: #{ex.message}" )
      nil
    end

    # Names of all top-level types/constants, for identifier completion.
    def top_level_type_names : Array(String)
      interpreter.program.types.keys
    rescue ex
      FLog.warn( "top_level_type_names failed: #{ex.message}" )
      [] of String
    end

    #--------------------------------------------------------------------------

    # The process-wide interpreter. Present after construction; guarded for safety.
    private def interpreter : Crystal::Repl
      @@interpreter || raise FReplError.new( "interpreter accessed before initialization" )
    end

    # Renders any non-fatal warnings attached to a result to a single string, or `nil`.
    private def collect_warnings ( warnings : Crystal::WarningCollection ) : String?
      io = IO::Memory.new
      warnings.report( io )
      io.to_s.presence
    rescue
      nil
    end

    # Best-effort human-readable description of an exception that can never itself raise,
    # so rendering a failure can never tear down the session.
    private def describe ( ex : Exception ) : String
      ex.to_s.presence || ex.message || ex.class.name
    rescue
      ex.class.name
    end

    private def load_prelude ( repl : Crystal::Repl ) : Nil
      repl.load_prelude
    rescue ex
      raise FPreludeError.new( "failed to load the Crystal prelude (CRYSTAL_PATH=#{ENV["CRYSTAL_PATH"]?}): #{ex.message}" )
    end

  end


end
