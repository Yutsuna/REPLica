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

    # Block level of the top-level scope, where the REPL's variables live.
    TOP_LEVEL_BLOCK = 0

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

      result = repl_instance.parse_and_interpret( source )
      FEvalOutcome.new( value: result.value.try( &.to_s ), warnings: collect_warnings( result.warnings ) )
    rescue ex : Exception
      # One arm covers every failure mode — compile/semantic errors
      # (`Crystal::CodeError`), uncaught interpreted exceptions
      # (`Crystal::Repl::EscapingException`) and anything else — because the UI
      # treats them identically: show the message, keep the session alive.
      FEvalOutcome.new( error: describe( ex ) )
    end

    #--------------------------------------------------------------------------

    # The shared interpreter, needed by `FReplReader` to seed the inherited
    # reader (parser context, highlighting, multi-line detection).
    def repl : Crystal::Repl
      repl_instance
    end

    # Compile-time type of a top-level local variable, or `nil` if unknown.
    def local_var_type ( name : String ) : Crystal::Type?
      low_level.local_vars.type?( name, TOP_LEVEL_BLOCK )
    rescue ex
      FLog.warn( "local_var_type(#{name}) failed: #{ex.message}" )
      nil
    end

    # Names of the local variables currently in scope at the top level.
    def local_var_names : Array(String)
      low_level.local_vars.names_at_block_level_zero.to_a
    rescue ex
      FLog.warn( "local_var_names failed: #{ex.message}" )
      [] of String
    end

    # Instance type of an arbitrary receiver expression
    # resolved by the compiler without executing user code, or `nil` when unresolvable.
    #
    # Expected typing failures surface as `nil` from the patch; an *unexpected*
    # exception (e.g. a compiler-API drift) propagates to here and is logged, so
    # a real bug is never silently mistaken for "type unknown".
    def infer_type ( receiver : String ) : Crystal::Type?
      return nil if receiver.blank?

      repl_instance.infer_type( receiver )
    rescue ex
      FLog.warn( "infer_type(#{receiver}) failed: #{ex.message}" )
      nil
    end

    # The top-level type/constant named *name* (e.g. `User`), or `nil` if there is none.
    def top_level_type ( name : String ) : Crystal::Type?
      repl_instance.program.types[name]?
    rescue ex
      FLog.warn( "top_level_type(#{name}) failed: #{ex.message}" )
      nil
    end

    # Names of all top-level types/constants, for identifier completion.
    def top_level_type_names : Array(String)
      repl_instance.program.types.keys
    rescue ex
      FLog.warn( "top_level_type_names failed: #{ex.message}" )
      [] of String
    end

    #--------------------------------------------------------------------------

    # The process-wide interpreter. Present after construction; guarded for safety.
    private def repl_instance : Crystal::Repl
      @@interpreter || raise FReplError.new( "interpreter accessed before initialization" )
    end

    # The low-level interpreter that owns the live local-variable table.
    private def low_level : Crystal::Repl::Interpreter
      repl_instance.interpreter
    end

    # Renders any non-fatal warnings attached to a result to a single string, or `nil`.
    # Best-effort: a rendering failure must never turn a successful eval into an error.
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
