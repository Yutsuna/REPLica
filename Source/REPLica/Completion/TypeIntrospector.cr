require "../Interpreter/CrystalPatches"


module REPLica


  # The single seam over `Crystal::Type` internals: enumerates the callable method
  # names of a type for autocompletion. Kept isolated so a Crystal version bump that
  # changes the type model touches only this file.
  module FTypeIntrospector

    extend self

    INTERNAL_PREFIX = "__"

    #--------------------------------------------------------------------------

    # Public instance-method names of *type*, including inherited ones, sorted & unique.
    def instance_methods ( type : Crystal::Type ) : Array(String)
      collect( type, type.ancestors )
    end

    # Public class-method names of *type* (its metaclass), including inherited ones.
    def class_methods ( type : Crystal::Type ) : Array(String)
      meta = type.metaclass
      collect( meta, meta.ancestors )
    end

    #--------------------------------------------------------------------------

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

    # Keeps real, callable identifiers; drops operators (`+`, `[]`, `<=>`…) and the
    # compiler's internal `__`-prefixed helpers, which are noise in a completion list.
    private def presentable? ( name : String ) : Bool
      return false if name.empty? || name.starts_with?( INTERNAL_PREFIX )

      first = name[0]
      first.ascii_letter? || first == '_'
    end

  end


end
