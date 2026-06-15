require "../../Source/REPLica/Completion/CompletionEngine"
require "../../Source/REPLica/Shell/ReplReader"

describe REPLica::FCompletionEngine do
  describe ".complete" do
    it "completes instance methods of a local variable" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "cmp_arr = [1, 2, 3]" )

      title, candidates = REPLica::FCompletionEngine.complete( bridge, "ma", "cmp_arr." ).not_nil!
      title.should eq( "Methods:" )
      candidates.should contain( "map" )
      candidates.all?( &.starts_with?( "ma" ) ).should be_true
    end

    it "completes class methods of a constant type without leaking instance methods" do
      bridge = REPLica::FInterpreterBridge.new

      title, candidates = REPLica::FCompletionEngine.complete( bridge, "", "String." ).not_nil!
      title.should eq( "Methods:" )
      candidates.should contain( "new" )
      candidates.should_not contain( "upcase" )
    end

    it "falls through to instance methods for a value constant (not a type)" do
      bridge = REPLica::FInterpreterBridge.new
      _, candidates = REPLica::FCompletionEngine.complete( bridge, "", "Math::PI." ).not_nil!
      candidates.should contain( "abs" )
    end

    it "completes instance methods of a chained (complex) receiver" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "cmp_nums = [1, 2, 3]" )

      _, candidates = REPLica::FCompletionEngine.complete( bridge, "", "cmp_nums.map { |n| n }." ).not_nil!
      candidates.should contain( "map" )
      candidates.should contain( "size" )
    end

    it "completes identifiers against locals and types, sorted" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "cmp_ident = 99" )

      title, candidates = REPLica::FCompletionEngine.complete( bridge, "cmp_ide", "" ).not_nil!
      title.should eq( "Suggestions:" )
      candidates.should contain( "cmp_ident" )
      candidates.should eq( candidates.sort )
    end

    it "returns a sorted result for member completion" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "cmp_sorted = [1, 2, 3]" )

      _, candidates = REPLica::FCompletionEngine.complete( bridge, "", "cmp_sorted." ).not_nil!
      candidates.should eq( candidates.sort )
    end

    it "returns nil for an unresolvable receiver (so the reader can fall back)" do
      bridge = REPLica::FInterpreterBridge.new
      REPLica::FCompletionEngine.complete( bridge, "", "definitely_unknown_xyz." ).should be_nil
    end

    it "returns nil for an empty receiver" do
      bridge = REPLica::FInterpreterBridge.new
      REPLica::FCompletionEngine.complete( bridge, "", "." ).should be_nil
    end

    it "returns nil when no candidate matches the filter" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "cmp_arr2 = [1, 2, 3]" )
      REPLica::FCompletionEngine.complete( bridge, "zzzzz_nomatch", "cmp_arr2." ).should be_nil
    end

    it "never executes a macro reached through the completion path" do
      bridge  = REPLica::FInterpreterBridge.new
      marker  = File.join( Dir.tempdir, "replica_complete_macro_#{Random.rand( 1_000_000 )}" )
      File.exists?( marker ).should be_false

      payload = %({{ system("touch #{marker}").stringify }}.)
      REPLica::FCompletionEngine.complete( bridge, "", payload ).should be_nil
      File.exists?( marker ).should be_false
    ensure
      File.delete( marker ) if marker && File.exists?( marker )
    end
  end
end

describe REPLica::FInterpreterBridge do
  describe "#infer_type" do
    it "infers the type of a chained receiver expression" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "infer_arr = [1, 2, 3]" )

      bridge.infer_type( "infer_arr.map { |n| n.to_s }" ).to_s.should contain( "Array" )
    end

    it "returns nil for an unresolvable expression" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.infer_type( "no_such_thing_at_all" ).should be_nil
    end

    it "returns nil for a blank expression" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.infer_type( "   " ).should be_nil
    end

    it "returns nil for an over-long expression instead of typing it" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.infer_type( "x" * 5000 ).should be_nil
    end

    it "rejects a macro expression without executing it (no RCE on TAB)" do
      bridge = REPLica::FInterpreterBridge.new
      marker = File.join( Dir.tempdir, "replica_infer_macro_#{Random.rand( 1_000_000 )}" )
      File.exists?( marker ).should be_false

      bridge.infer_type( %({{ system("touch #{marker}").stringify }}) ).should be_nil
      File.exists?( marker ).should be_false
    ensure
      File.delete( marker ) if marker && File.exists?( marker )
    end

    it "does not corrupt session state and stays usable after a failed inference" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "infer_keep = [10, 20, 30]" )
      names_before = bridge.local_var_names.size

      bridge.infer_type( "infer_keep.map { |x| x.to_s }" )
      bridge.infer_type( "1 +" )

      bridge.eval( "infer_keep" ).value.should eq( "[10, 20, 30]" )
      bridge.local_var_type( "infer_keep" ).to_s.should contain( "Array" )
      bridge.local_var_names.size.should eq( names_before )
      bridge.infer_type( "infer_keep.size" ).to_s.should contain( "Int32" )
    end
  end

  describe "#top_level_type" do
    it "resolves a known type and misses an unknown one" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.top_level_type( "String" ).should be_a( Crystal::Type )
      bridge.top_level_type( "NoSuchConstantXyz" ).should be_nil
    end
  end

  describe "#top_level_type_names" do
    it "lists prelude types" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.top_level_type_names.should contain( "String" )
    end
  end
end

describe REPLica::FReplReader do
  it "falls back to the inherited keyword completion for an unresolvable receiver" do
    bridge = REPLica::FInterpreterBridge.new
    reader = REPLica::FReplReader.new( bridge )

    REPLica::FCompletionEngine.complete( bridge, "", "unknown_recv_xyz." ).should be_nil

    title, candidates = reader.auto_complete( "", "unknown_recv_xyz." )
    title.should eq( "Keywords:" )
    candidates.should contain( "is_a?" )
  end

  it "uses type-aware completion when it applies" do
    bridge = REPLica::FInterpreterBridge.new
    reader = REPLica::FReplReader.new( bridge )
    bridge.eval( "reader_arr = [1, 2, 3]" )

    title, candidates = reader.auto_complete( "ma", "reader_arr." )
    title.should eq( "Methods:" )
    candidates.should contain( "map" )
  end
end
