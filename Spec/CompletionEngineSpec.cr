require "./SpecHelper"
require "../Source/REPLica/Completion/CompletionEngine"
require "../Source/REPLica/Shell/ReplReader"

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

    it "completes class methods of a constant type" do
      bridge = REPLica::FInterpreterBridge.new

      _, candidates = REPLica::FCompletionEngine.complete( bridge, "ne", "String." ).not_nil!
      candidates.should contain( "new" )
    end

    it "completes instance methods of a chained (complex) receiver" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "cmp_nums = [1, 2, 3]" )

      _, candidates = REPLica::FCompletionEngine.complete( bridge, "", "cmp_nums.map { |n| n }." ).not_nil!
      candidates.should contain( "map" )
      candidates.should contain( "size" )
    end

    it "completes identifiers against locals and types" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "cmp_ident = 99" )

      title, candidates = REPLica::FCompletionEngine.complete( bridge, "cmp_ide", "" ).not_nil!
      title.should eq( "Suggestions:" )
      candidates.should contain( "cmp_ident" )
    end

    it "returns nil for an unresolvable receiver" do
      bridge = REPLica::FInterpreterBridge.new
      REPLica::FCompletionEngine.complete( bridge, "", "definitely_unknown_xyz." ).should be_nil
    end

    it "returns nil when no candidate matches the filter" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "cmp_arr2 = [1, 2, 3]" )
      REPLica::FCompletionEngine.complete( bridge, "zzzzz_nomatch", "cmp_arr2." ).should be_nil
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

    it "does not corrupt session variable state while inferring" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "infer_keep = [10, 20, 30]" )

      bridge.infer_type( "infer_keep.map { |x| x.to_s }" )

      bridge.eval( "infer_keep" ).value.should eq( "[10, 20, 30]" )
      bridge.local_var_type( "infer_keep" ).to_s.should contain( "Array" )
    end
  end
end

describe REPLica::FReplReader do
  it "falls back to keyword completion for an unresolvable receiver" do
    bridge = REPLica::FInterpreterBridge.new
    reader = REPLica::FReplReader.new( bridge )

    _, candidates = reader.auto_complete( "", "unknown_recv_xyz." )
    candidates.should_not be_empty
  end

  it "uses type-aware completion when it applies" do
    bridge = REPLica::FInterpreterBridge.new
    reader = REPLica::FReplReader.new( bridge )
    bridge.eval( "reader_arr = [1, 2, 3]" )

    _, candidates = reader.auto_complete( "ma", "reader_arr." )
    candidates.should contain( "map" )
  end
end
