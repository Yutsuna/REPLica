require "../../Source/REPLica/Scanner/ShardReader"

describe REPLica::FShardReader do
  it "resolves the entry-point from targets.<name>.main in shard.yml" do
    with_project do |root|
      write_file( root, "shard.yml", "name: demo\ntargets:\n  demo:\n    main: Source/demo.cr\n" )
      write_file( root, "Source/demo.cr", "module Demo; end\n" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/demo.cr" ) )
    end
  end

  it "uses the first declared target when several exist" do
    with_project do |root|
      write_file( root, "shard.yml", "targets:\n  first:\n    main: Source/first.cr\n  second:\n    main: Source/second.cr\n" )
      write_file( root, "Source/first.cr" )
      write_file( root, "Source/second.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/first.cr" ) )
    end
  end

  it "falls back to Source/<dir-name>.cr when shard.yml has no targets" do
    with_project do |root|
      name = File.basename( root )
      write_file( root, "shard.yml", "name: whatever\n" )
      write_file( root, "Source/#{name}.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/#{name}.cr" ) )
    end
  end

  it "falls back to src/<dir-name>.cr (lowercase convention)" do
    with_project do |root|
      name = File.basename( root )
      write_file( root, "src/#{name}.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "src/#{name}.cr" ) )
    end
  end

  it "falls back to the first .cr file under a source dir, sorted" do
    with_project do |root|
      write_file( root, "Source/zeta.cr" )
      write_file( root, "Source/alpha.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/alpha.cr" ) )
    end
  end

  it "prefers Source/ over src/ in the bare-file fallback" do
    with_project do |root|
      write_file( root, "Source/from_source.cr" )
      write_file( root, "src/from_src.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/from_source.cr" ) )
    end
  end

  it "ignores a target whose main escapes the project root (traversal)" do
    with_project do |root|
      write_file( root, "shard.yml", "targets:\n  evil:\n    main: ../../../etc/passwd\n" )

      REPLica::FShardReader.find_entrypoint( root ).should be_nil
    end
  end

  it "ignores a target whose main is an absolute path outside the root" do
    with_project do |root|
      write_file( root, "shard.yml", "targets:\n  evil:\n    main: /etc/passwd\n" )

      REPLica::FShardReader.find_entrypoint( root ).should be_nil
    end
  end

  it "ignores a source file that symlinks outside the project root" do
    with_project do |root|
      outside = File.tempname( "replica_outside" )
      File.write( outside, "SECRET = 1\n" )
      Dir.mkdir_p( File.join( root, "Source" ) )
      File.symlink( outside, File.join( root, "Source/link.cr" ) )

      begin
        REPLica::FShardReader.find_entrypoint( root ).should be_nil
      ensure
        File.delete( outside ) if File.exists?( outside )
      end
    end
  end

  it "ignores a main that points to a non-existent file and tries conventions" do
    with_project do |root|
      name = File.basename( root )
      write_file( root, "shard.yml", "targets:\n  demo:\n    main: Source/missing.cr\n" )
      write_file( root, "Source/#{name}.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/#{name}.cr" ) )
    end
  end

  it "ignores a blank main value and tries conventions" do
    with_project do |root|
      name = File.basename( root )
      write_file( root, "shard.yml", "targets:\n  demo:\n    main: \"\"\n" )
      write_file( root, "Source/#{name}.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/#{name}.cr" ) )
    end
  end

  it "ignores a non-string main value and tries conventions" do
    with_project do |root|
      name = File.basename( root )
      write_file( root, "shard.yml", "targets:\n  demo:\n    main: 42\n" )
      write_file( root, "Source/#{name}.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/#{name}.cr" ) )
    end
  end

  it "ignores a target without a main key and tries conventions" do
    with_project do |root|
      name = File.basename( root )
      write_file( root, "shard.yml", "targets:\n  demo:\n    foo: bar\n" )
      write_file( root, "Source/#{name}.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/#{name}.cr" ) )
    end
  end

  it "survives a non-hash targets value and falls back to conventions" do
    with_project do |root|
      name = File.basename( root )
      write_file( root, "shard.yml", "targets: not_a_hash\n" )
      write_file( root, "Source/#{name}.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/#{name}.cr" ) )
    end
  end

  it "survives an empty targets mapping and falls back to conventions" do
    with_project do |root|
      name = File.basename( root )
      write_file( root, "shard.yml", "targets: {}\n" )
      write_file( root, "Source/#{name}.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/#{name}.cr" ) )
    end
  end

  it "survives a malformed shard.yml and falls back to conventions" do
    with_project do |root|
      name = File.basename( root )
      write_file( root, "shard.yml", "targets: [this: is, : not valid yaml" )
      write_file( root, "Source/#{name}.cr" )

      REPLica::FShardReader.find_entrypoint( root ).should eq( File.join( root, "Source/#{name}.cr" ) )
    end
  end

  it "returns nil when no shard.yml and no source dir exist" do
    with_project do |root|
      REPLica::FShardReader.find_entrypoint( root ).should be_nil
    end
  end

  it "returns nil when the source dir holds no .cr file" do
    with_project do |root|
      write_file( root, "Source/README.md", "# not crystal\n" )

      REPLica::FShardReader.find_entrypoint( root ).should be_nil
    end
  end

  it "returns nil for a non-existent project directory" do
    REPLica::FShardReader.find_entrypoint( "/nonexistent/path/replica/#{Random.rand(1_000_000)}" ).should be_nil
  end
end
