require "../../Source/REPLica/Completion/TypeIntrospector"

describe REPLica::FTypeIntrospector do
  describe ".instance_method_names" do
    it "lists public instance methods including inherited ones" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "introspect_int = 42" )

      methods = REPLica::FTypeIntrospector.instance_method_names( bridge, "introspect_int", true ).not_nil!
      methods.should contain( "to_s" )
      methods.should contain( "abs" )
    end

    it "drops operator methods from instance completion" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "introspect_int2 = 7" )

      methods = REPLica::FTypeIntrospector.instance_method_names( bridge, "introspect_int2", true ).not_nil!
      methods.should_not contain( "+" )
      methods.should_not contain( "[]" )
    end

    it "returns a sorted, de-duplicated list" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( %(introspect_str = "hi") )

      methods = REPLica::FTypeIntrospector.instance_method_names( bridge, "introspect_str", true ).not_nil!
      methods.should eq( methods.uniq )
      methods.should eq( methods.sort )
    end

    it "resolves a chained (complex) receiver without the local fast-path" do
      bridge = REPLica::FInterpreterBridge.new
      bridge.eval( "introspect_nums = [1, 2, 3]" )

      methods = REPLica::FTypeIntrospector.instance_method_names( bridge, "introspect_nums.map { |n| n }", false ).not_nil!
      methods.should contain( "map" )
      methods.should contain( "size" )
    end

    it "returns nil for an unresolvable receiver" do
      bridge = REPLica::FInterpreterBridge.new
      REPLica::FTypeIntrospector.instance_method_names( bridge, "no_such_receiver_zzz", true ).should be_nil
    end
  end

  describe ".class_method_names" do
    it "lists class methods through the metaclass, excluding instance methods" do
      bridge = REPLica::FInterpreterBridge.new

      methods = REPLica::FTypeIntrospector.class_method_names( bridge, "String" ).not_nil!
      methods.should contain( "new" )
      methods.should_not contain( "upcase" )
    end

    it "returns nil when the name is not a resolvable type" do
      bridge = REPLica::FInterpreterBridge.new
      REPLica::FTypeIntrospector.class_method_names( bridge, "NoSuchConstantXyz" ).should be_nil
    end
  end
end
