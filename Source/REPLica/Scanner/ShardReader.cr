require "yaml"
require "../Tools/Logger"


module REPLica


  # Discovers a host project's entry-point `.cr` file from its `shard.yml`.
  #
  # Resolution order:
  #   1. `targets.<name>.main` declared in shard.yml (first declared target wins)
  #   2. conventional `Source/<dir-name>.cr`, else `src/<dir-name>.cr`
  #   3. the first `.cr` file under `Source/`, else under `src/` (each dir sorted)
  #
  # Every candidate is validated to live inside the project root, symlinks included.
  #
  # So a malformed or hostile `shard.yml`, or a symlinked source file,
  # can never point the loader at a file outside the project.
  module FShardReader

    extend self

    SHARD_FILE  = "shard.yml"
    SOURCE_DIRS = ["Source", "src"]

    #--------------------------------------------------------------------------

    # Absolute path to the project's entry-point, or `nil` when none is found.
    def find_entrypoint ( project_dir : String ) : String?
      root = File.expand_path( project_dir )
      return nil unless Dir.exists?( root )

      from_shard( root ) || from_convention( root )
    end

    #--------------------------------------------------------------------------

    # Resolves `targets.<name>.main` from shard.yml, if present and valid.
    private def from_shard ( root : String ) : String?
      shard = File.join( root, SHARD_FILE )
      return nil unless File.file?( shard )

      main = parse_main( shard )
      return nil if main.nil?

      contain( root, main )
    end

    # Extracts the first non-blank `targets.<name>.main` value from shard.yml.
    private def parse_main ( shard_path : String ) : String?
      document = YAML.parse( File.read( shard_path ) )
      targets  = document["targets"]?
      return nil if targets.nil?

      targets.as_h.each_value do |target|
        main = target["main"]?.try( &.as_s? )
        return main if main && !main.blank?
      end
      nil
    rescue ex
      FLog.warn( "could not parse #{shard_path}: #{ex.message}" )
      nil
    end

    #--------------------------------------------------------------------------

    # Conventional fallbacks used when shard.yml has no usable target.
    private def from_convention ( root : String ) : String?
      name = File.basename( root )
      SOURCE_DIRS.each do |dir|
        if resolved = contain( root, File.join( dir, "#{name}.cr" ) )
          return resolved
        end
      end
      first_source_file( root )
    end

    # First `.cr` file directly under a known source directory (sorted for determinism).
    private def first_source_file ( root : String ) : String?
      SOURCE_DIRS.each do |dir|
        source_dir = File.join( root, dir )
        next unless Dir.exists?( source_dir )

        entries = source_files( source_dir )
        entries.each do |entry|
          candidate = File.join( source_dir, entry )
          return candidate if File.file?( candidate ) && within_root?( root, candidate )
        end
      end
      nil
    end

    # Sorted `.cr` entries directly under *source_dir*, empty if it cannot be listed.
    private def source_files ( source_dir : String ) : Array(String)
      Dir.children( source_dir ).select( &.ends_with?( ".cr" ) ).sort
    rescue ex
      FLog.warn( "could not list #{source_dir}: #{ex.message}" )
      [] of String
    end

    #--------------------------------------------------------------------------

    # Resolves *relative* against *root* and returns it only when it is an existing
    # file that stays inside *root*. Guards against traversal and absolute escapes.
    private def contain ( root : String, relative : String ) : String?
      resolved = File.expand_path( relative, root )
      return nil unless File.file?( resolved )
      return nil unless within_root?( root, resolved )

      resolved
    end

    # True when *resolved* lives inside *root* once symlinks on both sides are
    # canonicalised — so a symlinked file cannot escape the project tree.
    private def within_root? ( root : String, resolved : String ) : Bool
      real      = File.realpath( resolved )
      real_root = File.realpath( root )
      real == real_root || real.starts_with?( "#{real_root}#{File::SEPARATOR}" )
    rescue ex
      FLog.warn( "could not canonicalise #{resolved}: #{ex.message}" )
      false
    end

  end


end
