require "../Source/REPLica/Interpreter/InterpreterBridge"
require "spec"
require "file_utils"


def with_project ( & : String -> Nil ) : Nil
  root = File.tempname( "replica_spec" )
  Dir.mkdir_p( root )
  begin
    yield root
  ensure
    FileUtils.rm_rf( root )
  end
end

def write_file ( root : String, relative : String, content : String = "" ) : Nil
  path = File.join( root, relative )
  Dir.mkdir_p( File.dirname( path ) )
  File.write( path, content )
end
