require "compiler/crystal/interpreter"

module Crystal


  class Repl

    getter interpreter : Crystal::Repl::Interpreter

    # Infers the instance type of an arbitrary receiver expression without executing
    # it and without disturbing the persistent session.
    #
    # The expression is typed through `typeof(...)`
    # The compiler's side-effect-conscious typing construct (it never runs method bodies)
    # on a throwaway visitor, while `with_isolated_vars` snapshots and restores the live
    # visitor's variable bindings.
    #
    # Returns `nil` on any parse/semantic failure.
    def infer_type ( expression : String ) : Crystal::Type?
      node = new_parser( "typeof( #{expression} )" ).parse
      return nil if node.nil?

      resolved : Crystal::Type? = nil
      @main_visitor.with_isolated_vars do
        probe   = MainVisitor.new( from_main_visitor: @main_visitor )
        typed   = @program.semantic( @program.normalize( node ), main_visitor: probe )
        resolved = typed.type?
      end
      resolved.try( &.instance_type )
    rescue
      nil
    end

  end


  class MainVisitor

    # Runs the block with the visitor's variable bindings protected
    # Any mutation a probe semantic pass makes to the shared `@vars`/`@meta_vars`
    # is rolled back afterwards, so the live REPL session keeps its exact variable state.
    def with_isolated_vars ( & )
      saved_vars = @vars.dup
      saved_meta = @meta_vars.dup
      begin
        yield
      ensure
        @vars      = saved_vars
        @meta_vars = saved_meta
      end
    end
  end


end
