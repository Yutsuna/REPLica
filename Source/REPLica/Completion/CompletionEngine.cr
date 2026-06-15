require "../Interpreter/InterpreterBridge"
require "./ContextParser"
require "./TypeIntrospector"


module REPLica


  # Orchestrates type-aware autocompletion:
  #
  # |-> classifies the context
  # |-> resolves the receiver's methods through the cheapest safe path
  # |-> returns ranked candidates
  #
  # Pure string orchestration: every `Crystal::Type` stays behind `FTypeIntrospector`.
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
    # methods; a value (local var, value constant, chained expression) yields
    # instance methods. `nil` when the receiver is empty or its type is unresolvable.
    private def member_candidates ( bridge : FInterpreterBridge, context : FContextParser::Context ) : Array(String)?
      return nil if context.receiver.empty?

      if context.kind.constant?
        names = FTypeIntrospector.class_method_names( bridge, context.receiver )
        return names if names
      end

      FTypeIntrospector.instance_method_names( bridge, context.receiver, context.kind.local? )
    end

    private def identifier_candidates ( bridge : FInterpreterBridge ) : Array(String)
      ( bridge.local_var_names + bridge.top_level_type_names ).uniq
    end

    # Keeps only the candidates the partial name prefixes, always sorted.
    private def filter ( names : Array(String), name_filter : String ) : Array(String)
      selected = name_filter.empty? ? names : names.select( &.starts_with?( name_filter ) )
      selected.sort
    end

  end


end
