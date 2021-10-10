defmodule SimpleGrammer do
  import Gparse
  @doc "
    symbol := lowercase [ lowercase | digit ]*
    operator := '+' | '-' | '*' | '/'
    operand := symbol | integer | operation
    assignment := '(' '=' symbol operand ')'
    operation := '(' operator [ operand ]* ')' | assignment
  "
  def operation do
    lod = plowercase() |> a_or_b( pdigit() )
    symbol = plowercase() |> precedes_list( lod |> collect ) |> alter_result(fn e -> to_string(e) end)
    operator = [ string("+"), string("-"), string("*"), string("/")] |> pchoice

    w_ = pwhitespace() |> optional
    popen = string("(")
    operation_start = [popen, w_, operator, pwhitespace()] |> from_sequence_nth(2)
    pclose = string(")")
    operation_stop = [w_, pclose] |> sequence

    assignment = string("=")
    assign_sym = popen  |> keep_right( w_ ) |> keep_right( assignment )
                        |> keep_right( w_ ) |> keep_right( symbol ) |> keep_left( w_ )


    fn (e) ->
      operand = [symbol, pinteger() , e] |> pchoice
      operand_ = one_om_l(operand, pwhitespace())
      operation = operation_start |> precedes_list(operand_) |> keep_left( operation_stop )

      assign_ope = operand |> keep_left( w_ ) |> keep_left( pclose )
      assignment = [ assign_sym, assign_ope  ] |> sequence(true)

      operation |> a_or_b( assignment )
    end |> Gparse.Fix.fix2
  end
# o = operation()
# o.("(+ 1 2)")
end # module
