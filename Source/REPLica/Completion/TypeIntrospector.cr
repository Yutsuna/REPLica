require "../Interpreter/CrystalPatches"
require "../Interpreter/InterpreterBridge"


module REPLica


  # The single seam over `Crystal::Type` internals: enumerates the callable method
  # names of a receiver for autocompletion. Every `Crystal::Type` value lives and
  # dies inside this module, so a Crystal version bump that changes the type model
  # touches only this file (plus `CrystalPatches`).
  module FTypeIntrospector

    extend self

    INTERNAL_PREFIX = "__"

    #--------------------------------------------------------------------------

    # Public class-method names for the type named `name` (String, Hash...)
    # or `nil` when `name` is not a resolvable type/constant.
    def class_method_names ( bridge : FInterpreterBridge, name : String ) : Array(String)?
      type = bridge.top_level_type( name )
      type.nil? ? nil : class_methods( type )
    end

    # Public instance-method names of the `value` a receiver evaluates to, or `nil`
    # when the type cannot be resolved.
    # A local variable is resolved directly (free, side-effect-free)
    def instance_method_names ( bridge : FInterpreterBridge, receiver : String, allow_local : Bool ) : Array(String)?
      type = resolve_value_type( bridge, receiver, allow_local )
      type.nil? ? nil : instance_methods( type )
    end

    #--------------------------------------------------------------------------

    private def resolve_value_type ( bridge : FInterpreterBridge, receiver : String, allow_local : Bool ) : Crystal::Type?
      if allow_local
        bridge.local_var_type( receiver ) || bridge.infer_type( receiver )
      else
        bridge.infer_type( receiver )
      end
    end

    # Public instance-method names of `type`, including inherited ones, sorted & unique.
    private def instance_methods ( type : Crystal::Type ) : Array(String)
      collect( type, type.ancestors )
    end

    # Public class-method names of `type` (its metaclass), including inherited ones.
    private def class_methods ( type : Crystal::Type ) : Array(String)
      meta = type.metaclass
      collect( meta, meta.ancestors )
    end

    private def collect ( type : Crystal::Type, ancestors : Array(Crystal::Type) ) : Array(String)
      names = Set(String).new
      ancestors.each { |ancestor| gather( ancestor, names ) }
      gather( type, names )
      names.to_a.sort
    end

    private def gather ( type : Crystal::Type, names : Set(String) ) : Nil
      defs = type.defs
      return if defs.nil?

      defs.each do |name, overloads|
        names << name if presentable?( name ) && overloads.any?( &.def.visibility.public? )
      end
    end

    # Keeps real, callable identifiers; drops operators (`+`, `[]`, `<=>`...) and the
    # compiler's internal `__`-prefixed helpers, which are noise in a completion list.
    private def presentable? ( name : String ) : Bool
      return false if name.empty? || name.starts_with?( INTERNAL_PREFIX )

      first = name[0]
      first.ascii_letter? || first == '_'
    end

  end


end
