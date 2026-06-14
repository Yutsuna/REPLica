require "./SpecHelper"
require "../Source/REPLica/Completion/TypeIntrospector"

describe REPLica::FTypeIntrospector do
  it "lists public instance methods including inherited ones" do
    bridge = REPLica::FInterpreterBridge.new
    bridge.eval( "introspect_int = 42" )
    type = bridge.local_var_type( "introspect_int" ).not_nil!

    methods = REPLica::FTypeIntrospector.instance_methods( type )
    methods.should contain( "to_s" )
    methods.should contain( "abs" )
  end

  it "drops operator methods from instance completion" do
    bridge = REPLica::FInterpreterBridge.new
    bridge.eval( "introspect_int2 = 7" )
    type = bridge.local_var_type( "introspect_int2" ).not_nil!

    methods = REPLica::FTypeIntrospector.instance_methods( type )
    methods.should_not contain( "+" )
    methods.should_not contain( "[]" )
  end

  it "returns a sorted, de-duplicated list" do
    bridge = REPLica::FInterpreterBridge.new
    bridge.eval( %(introspect_str = "hi") )
    type = bridge.local_var_type( "introspect_str" ).not_nil!

    methods = REPLica::FTypeIntrospector.instance_methods( type )
    methods.should eq( methods.uniq )
    methods.should eq( methods.sort )
  end

  it "lists class methods through the metaclass" do
    bridge = REPLica::FInterpreterBridge.new
    type = bridge.top_level_type( "String" ).not_nil!

    REPLica::FTypeIntrospector.class_methods( type ).should contain( "new" )
  end
end
