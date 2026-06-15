require "../../Source/REPLica/Scanner/ObjectScanner"

describe REPLica::FObjectScanner do
  describe ".entrypoint_for" do
    it "returns the absolute path of a .cr file given directly" do
      with_project do |root|
        write_file( root, "Source/demo.cr" )
        file = File.join( root, "Source/demo.cr" )

        REPLica::FObjectScanner.entrypoint_for( file ).should eq( File.expand_path( file ) )
      end
    end

    it "rejects a file that is not Crystal source" do
      with_project do |root|
        write_file( root, "README.md", "# not crystal\n" )

        REPLica::FObjectScanner.entrypoint_for( File.join( root, "README.md" ) ).should be_nil
      end
    end

    it "discovers the entry-point of a directory via shard.yml" do
      with_project do |root|
        write_file( root, "shard.yml", "targets:\n  demo:\n    main: Source/demo.cr\n" )
        write_file( root, "Source/demo.cr" )

        REPLica::FObjectScanner.entrypoint_for( root ).should eq( File.join( root, "Source/demo.cr" ) )
      end
    end

    it "returns nil for a directory with no resolvable entry-point" do
      with_project do |root|
        REPLica::FObjectScanner.entrypoint_for( root ).should be_nil
      end
    end

    it "returns nil for a path that is neither a file nor a directory" do
      REPLica::FObjectScanner.entrypoint_for( "/nonexistent/replica/#{Random.rand(1_000_000)}.cr" ).should be_nil
    end
  end

  describe ".autoload" do
    it "loads a discovered project into the live session" do
      with_project do |root|
        bridge = REPLica::FInterpreterBridge.new
        token  = "ScannerFixture#{Random.rand(1_000_000)}"
        write_file( root, "shard.yml", "targets:\n  demo:\n    main: Source/demo.cr\n" )
        write_file( root, "Source/demo.cr", "module #{token}\n  VALUE = 42\nend\n" )

        REPLica::FObjectScanner.autoload( bridge, root ).should be_true
        bridge.eval( "#{token}::VALUE" ).value.should eq( "42" )
      end
    end

    it "returns false and keeps the session alive when nothing can be loaded" do
      with_project do |root|
        bridge = REPLica::FInterpreterBridge.new
        REPLica::FObjectScanner.autoload( bridge, root ).should be_false
        bridge.eval( "1 + 1" ).value.should eq( "2" )
      end
    end

    it "returns false and leaves no partial definitions when the entry-point fails to compile" do
      with_project do |root|
        bridge = REPLica::FInterpreterBridge.new
        token  = "BadFixture#{Random.rand(1_000_000)}"
        write_file( root, "shard.yml", "targets:\n  demo:\n    main: Source/demo.cr\n" )
        write_file( root, "Source/demo.cr", "module #{token}\n  VALUE = 1\nend\nthis is not valid @@@\n" )

        REPLica::FObjectScanner.autoload( bridge, root ).should be_false
        # The whole file fails to parse, so nothing it declared may leak in.
        bridge.eval( "#{token}::VALUE" ).ok?.should be_false
        bridge.eval( "2 + 2" ).value.should eq( "4" )
      end
    end

    it "does not let a quote in the entry-point filename inject code" do
      with_project do |root|
        bridge = REPLica::FInterpreterBridge.new
        # If the require string were not escaped, the embedded quote would close
        # it and the trailing assignment would run as top-level Crystal.
        evil = "a\";INJECTED_CONST=1;b.cr"
        write_file( root, "Source/#{evil}", "# harmless\n" )

        REPLica::FObjectScanner.autoload( bridge, root )
        bridge.eval( "INJECTED_CONST" ).ok?.should be_false
      end
    end
  end
end
