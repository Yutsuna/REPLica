require "../../Source/REPLica/Completion/ContextParser"

describe REPLica::FContextParser do
  it "treats a trailing dot as member access on a local variable" do
    context = REPLica::FContextParser.classify( "arr." )
    context.member_access.should be_true
    context.receiver.should eq( "arr" )
    context.kind.local?.should be_true
  end

  it "classifies a capitalized receiver as a constant" do
    context = REPLica::FContextParser.classify( "User." )
    context.member_access.should be_true
    context.receiver.should eq( "User" )
    context.kind.constant?.should be_true
  end

  it "classifies a namespaced path as a constant" do
    REPLica::FContextParser.classify( "Foo::Bar." ).kind.constant?.should be_true
  end

  it "classifies a chained expression as complex" do
    context = REPLica::FContextParser.classify( "users.filter { |u| u.age > 18 }." )
    context.member_access.should be_true
    context.receiver.should eq( "users.filter { |u| u.age > 18 }" )
    context.kind.complex?.should be_true
  end

  it "classifies a literal receiver as complex" do
    REPLica::FContextParser.classify( "[1, 2, 3]." ).kind.complex?.should be_true
  end

  it "classifies a method call on a namespaced constant as complex" do
    context = REPLica::FContextParser.classify( "Foo::Bar.baz." )
    context.receiver.should eq( "Foo::Bar.baz" )
    context.kind.complex?.should be_true
  end

  it "classifies a generic type literal as complex" do
    REPLica::FContextParser.classify( "Hash(String, Int32)." ).kind.complex?.should be_true
  end

  it "recognises predicate/bang identifiers as locals" do
    REPLica::FContextParser.classify( "ready?." ).kind.local?.should be_true
  end

  it "is not member access without a trailing dot" do
    REPLica::FContextParser.classify( "arr" ).member_access.should be_false
  end

  it "is not member access for an empty expression" do
    REPLica::FContextParser.classify( "" ).member_access.should be_false
  end

  it "tolerates whitespace around the trailing dot" do
    context = REPLica::FContextParser.classify( "arr .  " )
    context.member_access.should be_true
    context.receiver.should eq( "arr" )
  end
end
