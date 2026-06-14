require "./SpecHelper"

describe REPLica::FInterpreterBridge do
  it "persists local variables across evaluations" do
    bridge.eval("x = 40").value.should eq("40")
    bridge.eval("x + 2").value.should eq("42")
  end

  it "keeps method definitions available across evaluations" do
    bridge.eval("def double( n ); n * 2; end")
    bridge.eval("double(21)").value.should eq("42")
  end

  it "keeps multi-line class definitions available across evaluations" do
    bridge.eval("class Widget\n  def answer; 42; end\nend")
    bridge.eval("Widget.new.answer").value.should eq("42")
  end

  it "renders values through the interpreter's inspect" do
    bridge.eval(%(greeting = "hi")).value.should eq(%("hi"))
    bridge.eval("[1, 2, 3]").value.should eq("[1, 2, 3]")
    bridge.eval("nil").value.should eq("nil")
    bridge.eval("true").value.should eq("true")
    bridge.eval(%({"a" => 1})).value.should eq(%({"a" => 1}))
  end

  it "treats blank input as a no-op (no value, no error)" do
    outcome = bridge.eval("   ")
    outcome.ok?.should be_true
    outcome.has_value?.should be_false
    outcome.value.should be_nil
  end

  it "treats truly empty input as a no-op" do
    bridge.eval("").has_value?.should be_false
  end

  it "captures a syntax error and keeps the session usable" do
    outcome = bridge.eval("1 +")
    outcome.ok?.should be_false
    outcome.error.should_not be_nil
    bridge.eval("1 + 1").value.should eq("2")
  end

  it "captures a semantic error and keeps the session usable" do
    outcome = bridge.eval("definitely_undefined_method_xyz(1)")
    outcome.ok?.should be_false
    outcome.has_value?.should be_false
    bridge.eval("2 + 3").value.should eq("5")
  end

  it "captures a runtime exception without dying" do
    outcome = bridge.eval(%(raise "boom"))
    outcome.ok?.should be_false
    outcome.error.not_nil!.should contain("boom")
    bridge.eval("7 * 6").value.should eq("42")
  end

  it "resolves the type of a top-level local variable" do
    bridge.eval("counter = 123")
    bridge.local_var_type("counter").to_s.should eq("Int32")
    bridge.local_var_names.should contain("counter")
  end

  it "reflects a variable's type after reassignment to another type" do
    bridge.eval("flexible = 1")
    bridge.eval(%(flexible = "now a string"))
    bridge.local_var_type("flexible").to_s.should contain("String")
  end

  it "returns nil type for an unknown variable" do
    bridge.local_var_type("definitely_unknown").should be_nil
  end

  it "exposes the live program and the shared interpreter" do
    bridge.program.should be_a(Crystal::Program)
    bridge.repl.should be_a(Crystal::Repl)
    bridge.repl.should be(bridge.repl)
  end
end
