require "../Tools/Logger"


module REPLica


  # Resolves and configures CRYSTAL_PATH for the in-process interpreter.
  #
  # The interpreter we link (`Crystal::Repl`) loads the prelude through the embedded
  # compiler's path resolution. `Crystal::Config.path` is baked empty into our binary,
  # so without help the prelude cannot be found.
  #
  # This module makes CRYSTAL_PATH point at the standard library and, optionally, a host project's `lib/` so its shards resolve.
  module FCrystalEnv

    extend self

    # TODO: double check that
    PATH_DELIMITER = {% if flag?( :windows ) %} ";" {% else %} ":" {% end %}

    FALLBACK_STDLIB = "/usr/lib/crystal"

    @@stdlib : String? = nil

    #--------------------------------------------------------------------------

    def stdlib_path : String
      @@stdlib ||= detect_stdlib
    end

    def configure ( project_lib : String? = nil ) : Nil
      base  = stdlib_path
      parts = [] of String
      parts << project_lib if project_lib && Dir.exists?( project_lib )
      parts << base
      ENV["CRYSTAL_PATH"] = parts.join( PATH_DELIMITER )
    end

    #--------------------------------------------------------------------------

    private def detect_stdlib : String
      if env = ENV["CRYSTAL_PATH"]?
        return env unless env.blank?
      end

      query_compiler_path || FALLBACK_STDLIB
    end

    # Asks the `crystal` toolchain for its own CRYSTAL_PATH.
    private def query_compiler_path : String?
      output = IO::Memory.new
      status = Process.run( "crystal", ["env", "CRYSTAL_PATH"], output: output, error: Process::Redirect::Close )
      unless status.success?
        FLog.warn( "`crystal env CRYSTAL_PATH` exited #{status.exit_code}; falling back to #{FALLBACK_STDLIB}" )
        return nil
      end

      path = output.to_s.strip
      path.blank? ? nil : path
    rescue ex
      FLog.warn( "could not query the crystal toolchain (#{ex.message}); falling back to #{FALLBACK_STDLIB}" )
      nil
    end

  end


end
