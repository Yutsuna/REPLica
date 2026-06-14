require "../Interpreter/CrystalEnv"


module REPLica


  # Resolves a host project's `lib/` search paths for the interpreter.
  module FProjectContext

    extend self

    #--------------------------------------------------------------------------

    # `lib/` directories to put on the interpreter's search path: the current
    # working directory's `lib/` and the resolved project root's `lib/`.
    def get_joined_lib ( bootstrap_path : String ) : String
      project_libs = [] of String
      project_libs << File.expand_path( "lib" )
      project_root = find_project_root( bootstrap_path )
      project_libs << File.join( project_root, "lib" )
      project_libs.uniq.join( FCrystalEnv::PATH_DELIMITER )
    end

    #--------------------------------------------------------------------------

    # Walks up from *path* to the first directory holding a `lib/` or `shard.yml`,
    # falling back to *path* itself (or its parent) when none is found.
    private def find_project_root ( path : String ) : String
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
