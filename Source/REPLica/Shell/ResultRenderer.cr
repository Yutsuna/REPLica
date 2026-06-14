require "../Interpreter/InterpreterBridge"
require "../Tools/Logger"


module REPLica


  # Renders the outcome of an evaluation to the terminal.
  #
  # Succes:   `=> <value>`
  # Error:    `<error message>` (in red)
  # Warning:  `<warning message>` (in yellow)
  #
  # Syntax-highlighted on a TTY through Crystal's own highlighter
  module FResultRenderer

    extend self

    RESULT_PREFIX = " => "

    #--------------------------------------------------------------------------

    def render ( outcome : FEvalOutcome, io : IO = STDOUT ) : Nil
      if warnings = outcome.warnings
        render_warnings( warnings, io )
      end

      if error = outcome.error
        render_error( error, io )
      elsif value = outcome.value
        render_value( value, io )
      end
      io.flush
    end

    #--------------------------------------------------------------------------

    private def render_value ( value : String, io : IO ) : Nil
      io << RESULT_PREFIX
      io.puts( highlight( value, io ) )
    end

    private def render_warnings ( warnings : String, io : IO ) : Nil
      text = warnings.chomp
      if color?( io )
        io.puts( "#{EAnsiColor::YELLOW}#{text}#{EAnsiColor::RESET}" )
      else
        io.puts( text )
      end
    end

    private def render_error ( error : String, io : IO ) : Nil
      if color?( io )
        io.puts( "#{EAnsiColor::RED}#{error}#{EAnsiColor::RESET}" )
      else
        io.puts( error )
      end
    end

    private def highlight ( value : String, io : IO ) : String
      return value unless color?( io )

      Crystal::SyntaxHighlighter::Colorize.highlight!( value )
    rescue
      value
    end

    private def color? ( io : IO ) : Bool
      io.is_a?( IO::FileDescriptor ) && io.tty?
    end

  end


end
