module REPLica


  module FProjectContext

    #--------------------------------------------------------------------------

    def self.get_joined_lib(bootstrap_path : String) : String
      project_libs = [] of String
      project_libs << File.expand_path( "lib" )
      project_root = find_project_root( bootstrap_path )
      project_libs << File.join( project_root, "lib" )
      project_libs.uniq.join( FCrystalEnv::PATH_DELIMITER )
    end

    def self.get_crystal_require_path_format(bootstrap_path : String) : String
      absolute_path = File.expand_path( bootstrap_path )
      relative_path = Path[absolute_path].relative_to( Dir.current ).to_s
      relative_path = "./" + relative_path unless relative_path.starts_with?( '.' )
      relative_path
    end

    #--------------------------------------------------------------------------

    private def self.find_project_root(path : String) : String
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
