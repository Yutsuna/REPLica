require "../Interpreter/InterpreterBridge"
require "./ContextParser"
require "./TypeIntrospector"


module REPLica


  # Orchestrates type-aware autocompletion:
  #
  # |-> Classifies the context
  # |-> resolve the receiver's type throught the cheapest safe path
  # |-> return ranked candidates
  #
  # Returns `nil` when nothing type-aware applies, so the reader can fall back to its
  # inherited keyword completion.
  module FCompletionEngine

    extend self

    MEMBER_TITLE     = "Methods:"
    IDENTIFIER_TITLE = "Suggestions:"

    #--------------------------------------------------------------------------

    def complete ( bridge : FInterpreterBridge, name_filter : String, expression : String ) : {String, Array(String)}?
      context    = FContextParser.classify( expression )
      candidates = context.member_access ? member_candidates( bridge, context ) : identifier_candidates( bridge )
      return nil if candidates.nil?

      matches = filter( candidates, name_filter )
      return nil if matches.empty?

      { context.member_access ? MEMBER_TITLE : IDENTIFIER_TITLE, matches }
    end

    #--------------------------------------------------------------------------

    # Methods of the receiver's type. A constant naming a type yields its class
    # methods; every value (local var, chained expression, value constant) yields
    # instance methods. `nil` when the type cannot be resolved.
    private def member_candidates ( bridge : FInterpreterBridge, context : FContextParser::Context ) : Array(String)?
      if context.kind.constant?
        if type = bridge.top_level_type( context.receiver )
          return FTypeIntrospector.class_methods( type )
        end
      end

      type = resolve_value_type( bridge, context )
      type.nil? ? nil : FTypeIntrospector.instance_methods( type )
    end

    # Resolves the receiver as a *value*: a local variable directly, otherwise via the
    # compiler's side-effect-free type inference.
    private def resolve_value_type ( bridge : FInterpreterBridge, context : FContextParser::Context ) : Crystal::Type?
      if context.kind.local?
        bridge.local_var_type( context.receiver ) || bridge.infer_type( context.receiver )
      else
        bridge.infer_type( context.receiver )
      end
    end

    private def identifier_candidates ( bridge : FInterpreterBridge ) : Array(String)
      ( bridge.local_var_names + bridge.top_level_type_names ).uniq
    end

    private def filter ( names : Array(String), name_filter : String ) : Array(String)
      return names.sort if name_filter.empty?

      names.select( &.starts_with?( name_filter ) ).sort
    end

  end


end
