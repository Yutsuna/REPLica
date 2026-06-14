module REPLica


  # Classifies the text before the cursor into a completion context.
  #
  # Because `.` is a word delimiter in the reader, `expression` already ends with `.`
  # for member access and the partial method name is delivered separately. So the
  # receiver is simply the text before that trailing `.`.
  module FContextParser

    extend self

    # How the receiver should be resolved to a type.
    enum EReceiverKind
      Local    #<< bare lowercase identifier ( `my_var` )       -> local variable
      Constant #<< `Capitalized` or `A::B` path                 -> a type/constant
      Complex  #<< anything else ( chained calls, literals... ) -> needs semantic typing
    end

    record Context,
      member_access : Bool,
      receiver : String,
      kind : EReceiverKind

    IDENTIFIER = /\A[a-z_][A-Za-z0-9_]*[?!]?\z/
    CONSTANT   = /\A[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*\z/

    #--------------------------------------------------------------------------

    # Classifies *expression* (the text before the cursor's current word).
    def classify ( expression : String ) : Context
      text = expression.rstrip
      if text.ends_with?( '.' )
        receiver = text[0...-1].strip
        Context.new( member_access: true, receiver: receiver, kind: kind_of( receiver ) )
      else
        Context.new( member_access: false, receiver: "", kind: EReceiverKind::Complex )
      end
    end

    #--------------------------------------------------------------------------

    private def kind_of ( receiver : String ) : EReceiverKind
      case receiver
      when IDENTIFIER then EReceiverKind::Local
      when CONSTANT   then EReceiverKind::Constant
      else                 EReceiverKind::Complex
      end
    end

  end


end
