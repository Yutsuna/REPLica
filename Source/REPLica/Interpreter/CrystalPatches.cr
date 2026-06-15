require "compiler/crystal/interpreter"

module Crystal


  # Flags whether an AST contains any macro construct.
  class FReplMacroGuard < Visitor

    getter macro_present : Bool = false

    def visit ( node : ASTNode ) : Bool
      if node.is_a?( MacroExpression ) || node.is_a?( MacroLiteral ) ||
         node.is_a?( MacroVerbatim ) || node.is_a?( MacroIf ) ||
         node.is_a?( MacroFor ) || node.is_a?( MacroVar )
        @macro_present = true
      end
      !@macro_present #<< stop descending as soon as a macro is found
    end

  end


  class Repl

    getter interpreter : Crystal::Repl::Interpreter

    # Receiver text longer than this is never typed: a completion receiver is
    # short, and an unbounded expression would let a single TAB run an
    # arbitrarily expensive semantic pass.
    INFER_MAX_EXPRESSION_BYTES = 4096

    #--------------------------------------------------------------------------

    # Infers the instance type of an arbitrary receiver expression without executing
    # it and without disturbing the persistent session.
    #
    # The expression is typed through `typeof(...)`, the compiler's
    # side-effect-conscious typing construct (it never runs method bodies), on a
    # throwaway visitor, while `with_isolated_vars` snapshots and restores the
    # live visitor's variable bindings.
    #
    # Any expression carrying a macro node is rejected outright (returns `nil`):
    # macro expansion is the only code that runs at type-check time, so it must
    # never be reachable from completion.
    #
    # Returns `nil` on rejection or on any parse/semantic failure
    # (`Crystal::CodeError`). Unexpected exceptions propagate so the caller can
    # log them rather than silently mistaking a bug for "type unknown".
    def infer_type ( expression : String ) : Crystal::Type?
      return nil if expression.bytesize > INFER_MAX_EXPRESSION_BYTES

      node = new_parser( "typeof( #{expression} )" ).parse
      return nil if node.nil?
      return nil if contains_macro?( node )

      resolved : Crystal::Type? = nil
      @main_visitor.with_isolated_vars do
        probe    = MainVisitor.new( from_main_visitor: @main_visitor )
        typed    = @program.semantic( @program.normalize( node ), main_visitor: probe )
        resolved = typed.type?
      end
      resolved.try( &.instance_type )
    rescue Crystal::CodeError
      nil
    end

    #--------------------------------------------------------------------------

    private def contains_macro? ( node : ASTNode ) : Bool
      guard = FReplMacroGuard.new
      node.accept( guard )
      guard.macro_present
    end

  end


  class MainVisitor

    #--------------------------------------------------------------------------

    # Runs the block with the visitor's variable bindings protected.
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
