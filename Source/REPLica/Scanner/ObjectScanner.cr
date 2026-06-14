require "../Interpreter/InterpreterBridge"
require "../Tools/Logger"
require "./ShardReader"


module REPLica


  # Auto-loads a host project into the live interpreter (zero-config bootstrap).
  #
  # `bootstrap_path` may be either a specific `.cr` file or a project directory
  # whose entry-point is discovered from its `shard.yml` (see `FShardReader`).
  module FObjectScanner

    extend self

    CRYSTAL_EXT = ".cr"

    #--------------------------------------------------------------------------

    # Requires the project's entry-point into *bridge*.
    #
    # Returns `true` once the project's code is available in the session, `false`
    # when there is nothing to load or the require failed — in every case the
    # session stays alive so the user still gets a working prompt.
    def autoload ( bridge : FInterpreterBridge, bootstrap_path : String ) : Bool
      entrypoint = entrypoint_for( bootstrap_path )
      return false if entrypoint.nil?

      load( bridge, entrypoint )
    end

    #--------------------------------------------------------------------------

    # Absolute entry-point path for a `.cr` file or a project directory, or `nil`
    # (with a warning) when none can be resolved.
    #
    # Public so it can be exercised in isolation, without booting an interpreter.
    def entrypoint_for ( bootstrap_path : String ) : String?
      if File.file?( bootstrap_path )
        return File.expand_path( bootstrap_path ) if bootstrap_path.ends_with?( CRYSTAL_EXT )

        FLog.warn( "#{bootstrap_path} is not a Crystal source file; starting a bare session" )
        nil
      elsif File.directory?( bootstrap_path )
        resolved = FShardReader.find_entrypoint( bootstrap_path )
        FLog.warn( "no entry-point found under #{bootstrap_path}; starting a bare session" ) if resolved.nil?
        resolved
      else
        FLog.warn( "#{bootstrap_path} is neither a file nor a directory; starting a bare session" )
        nil
      end
    end

    #--------------------------------------------------------------------------

    # Requires *entrypoint* into the session, reporting progress through `FLog`.
    private def load ( bridge : FInterpreterBridge, entrypoint : String ) : Bool
      FLog.step( "Loading #{entrypoint}..." )

      outcome = bridge.eval( require_statement( entrypoint ) )
      if outcome.ok?
        FLog.ok( "Loaded #{entrypoint}." )
        true
      else
        FLog.error( "Failed to load #{entrypoint}:\n#{outcome.error}" )
        false
      end
    end

    # Builds a `require` statement for entrypoint..
    private def require_statement ( entrypoint : String ) : String
      relative = Path[entrypoint].relative_to( Dir.current ).to_s
      relative = "./#{relative}" unless relative.starts_with?( '.' )
      %(require #{relative.inspect})
    end

  end


end
