require "./REPLica/**"


module REPLica


  def self.launch ( bootstrap_path : String )
    FShell.run( bootstrap_path )
  end


end

unless ARGV.size == 1
  REPLica::FLog.error( "usage: REPLica <project-path>" )
  exit 1
end

REPLica.launch( ARGV[0] )
