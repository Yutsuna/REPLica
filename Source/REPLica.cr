require "./REPLica/**"


module REPLica


  def self.launch ( bootstrap_path : String? ) : Nil
    FShell.run( bootstrap_path )
  end


end

REPLica.launch( ARGV[0]? )
