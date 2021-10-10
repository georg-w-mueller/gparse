defmodule Gparse do
  @moduledoc """
  Documentation for Gparse.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Gparse.hello
      :world

  """
  def hello do
    :world
  end

  @typedoc """
  A successful result.

  `{:ok, RESULT, REMAINDER, NEW_POSITION}`
  """
  @type ok :: {:ok, any, String.t, Integer.t}
  @typedoc """
  A failed result.

  `{:error, ERROR_MESSAGE, POSITION}`
  """
  @type error :: {:error, String.t, Integer.t}
  @type parser :: (String.t, Integer.t -> ok | error)

  def item_or_list_of_items(pl, sep, popen, pclose) when is_list(pl) do
    pl |> pchoice |> nested_list(popen, pclose, sep)
  end

  def pchoice( [] ) do
    fn target, pos -> {:error, "Nothing matched #{target}/#{pos}", pos} end
  end
  def pchoice( [h | t] ) do
    h |> a_or_b(pchoice(t))
  end

  @doc "Nested list with ('p's or list) inside st, ed, separed by sep"
  def nested_list(p, st, ed, sep) do
    fn (e) ->
        a_or_b(p, e) |> one_om_l(sep) |> between(st, ed)
        # a_or_b(p, e) |> single_or_many_separated(sep) |> between(st, ed) ,
        # [ st, a_or_b(p, e) |> single_or_many_separated(sep), ed] |> sequence,
    end |> Gparse.Fix.fix2
  end

  def one_om_l(p, s) do
    cont = s |> keep_right(p) |> collect
    p |> precedes_list(cont) |> a_or_b( [ p ] |> sequence )
  end

  def precedes_list(left, right) do
    fn target, pos ->
      case both(left, right).(target, pos) do
        {{:ok, lf, _, _}, {:ok, rf, rrem, rpos}} -> {:ok, [lf | rf] , rrem, rpos}
        x -> x
      end
    end
  end

  def both(a, b) do
    fn target, pos ->
      case a.(target, pos) do
        {:ok, af, arem, apos} ->
          case b.(arem, apos) do
            {:ok, bf, brem, bpos} -> {{:ok, af, arem, apos}, {:ok, bf, brem, bpos}}
            berr -> berr
          end
        aerr -> aerr
      end
    end
  end

  def single_or_many_separated(p, sep) do
    # sequencer = fn seq -> sequence_lift_subresults(seq, false) end;
    # fn (e) ->
    #   a_or_b( [p, sep, e ] |> sequence_without_nth(1, sequencer),
    #           p )
    # end |> Gparse.Fix.fix2

    # sequencer = fn seq -> sequence_lift_subresults(seq, false) end;
    store = Gparse.Fix.fstore()
    fn (e) ->
      a_or_b( p |> keep_left(sep) |> pand_r(e, store),
              p )
             #
    end |> Gparse.Fix.fix2 |> alter_result(&pred/1)
  end

  defp pred(r) when is_function(r,2), do: r.(:yield, nil)
  defp pred(r), do: r

  def pand_r(l, r, stf) do
    fn (target, pos) ->
      case l.(target, pos) do
        {:ok, lf, lrem, lpos} ->
          case r.(lrem, lpos) do
            {:ok, rf, rrem, rpos} -> {:ok, stf.(:store, lf).(:store, rf) , rrem, rpos }
            rfail -> rfail
          end # case r
        lfail -> lfail
      end # case l
    end # fn
  end # pand

  def pfloat do
    pd = pdigit()
    onumbersign = anyfrom("+-") |> optional
    [ onumbersign, pd, pd |> collect, string("."), pd |> collect ] |> sequence(true) #|> drop_empty
    |> alter_result( fn e -> shrink(e) |> to_string |> Float.parse
    |> case  do
          {r, ""} -> r
          x -> throw "Shall not happen: failed Float.parse (#{x})."
        end
    end)
  end

  def pinteger do
    pd = pdigit()
    onumbersign = anyfrom("+-") |> optional
    [ onumbersign, pd, pd |> collect ] |> sequence(true) #|> drop_empty
    |> sequence_to_integer
  end

  def plowercases, do: plowercase() |> one_or_many |> sequence_to_string

  def plowercase do
    (for n <- ?a..?z, do: n) |> anyfrom
  end

  def pdigit do
    (for n <- ?0..?9, do: n) |> anyfrom
  end

  def pwhitespace do
    w = pwhite()
    #[w, w |> collect] |> sequence
    one_or_many(w)
    |> sequence_to_string #alter_result( fn e -> shrink(e) |> to_string end)
  end

  def pwhite do
    ['\s', 32, '\t', 9, '\n', 10] |> anyfrom
  end

  def between(p, left, right), do: left |> keep_right(p) |> keep_left(right)

  @doc "If the ok-result is not a list than wrap it as list"
  def ensure_list( p ) do
    p |> alter_result(
      fn
        l when is_list(l) -> l
        nl -> [nl]
      end)
  end

  def from_sequence_nth(ps, n) when is_list(ps) and is_integer(n) do
    ps |> sequence |> alter_result(
      fn e-> take_nth(e, n) end)
  end

  def sequence_without_nth( ps, n ) when is_list(ps) and is_integer(n) do
    ps |> sequence |> alter_result(
      fn e-> remove_nth(e, n) end)
  end

  def sequence_without_nth( ps, n, sequencer ) when is_list(ps) and is_integer(n) and is_function(sequencer) do
    ps |> sequencer.() |> alter_result(
      fn e-> remove_nth(e, n) end)
  end

  def take_nth(l, n) when is_list(l) and is_integer(n), do: Enum.at(l, n)
  def remove_nth(l, n) when is_list(l) and is_integer(n), do: List.delete_at(l, n)

  def shrink( l ) when is_list(l) do
    Enum.reduce(l, [], fn
      e,c -> case(e) do
        {:ok, lr, _, _} ->
          if is_list(lr) do
            c ++ lr
          else
            c ++ [lr]
          end
        x -> throw "Cannot shrink non-ok-result #{inspect(x, charlist: :as_list)}."
      end
    end)
  end

  def sequence_to_string( p ), do: p|> alter_result( fn e -> shrink(e) |> to_string end)

  def sequence_to_integer( p ) do
    p |> sequence_to_string |> alter_result(
      fn e -> Integer.parse(e) |> case do
        {i, ""} -> i
        _ -> "Shall not happen: Integer.parse."
      end
    end)
  end

  def optional( p ) do
    fn target, pos ->
      case (p.(target, pos)) do
        {:ok, _,_,_} = res -> res
        _ -> {:ok, :empty, target, pos}
      end
    end
  end

  def drop_empty(p), do: keep(p, fn e -> not match?( {:ok, :empty, _, _}, e) end)

  def keep(p, f) do
    fn target, pos ->
      case p.(target, pos) do
        {:ok, sr, rem, rpos} when is_list(sr) -> {:ok, Enum.filter(sr, f), rem, rpos}
        x -> x  # throw "Cannot drop from single."
      end
    end
  end

  def a_or_b(fa, fb) do
    fn target, pos ->
      case fa.(target, pos) do
        {:ok, _,_,_} = res -> res
        _ -> fb.(target, pos)
      end
    end
  end

  def keep_right(left, right), do: keep_lr(left, right, fn _,r -> r end)
  def keep_left(left, right), do: keep_lr(left, right, fn l,_ -> l end)

  defp keep_lr(left, right, selector) do
    fn target, pos ->
      case left.(target, pos) do
        {:ok, lfinding, lrem, lpos} ->
          case right.(lrem, lpos) do
            {:ok, rfinding, rrem, rpos} -> {:ok, selector.(lfinding, rfinding), rrem, rpos }
            x -> x
          end
        x -> x
      end
    end
  end

  def tag_result(p, tg) when is_function(p) and is_atom(tg) do
    fn target, pos ->
      case p.(target, pos) do
        {:ok, lr, reminder, lpos} -> {:ok, {tg, lr}, reminder, lpos}
        x -> x
      end
    end
  end

  @doc "Applies given function to the parsers ok-result."
  def alter_result(p, f) when is_function(p) and is_function(f) do
    fn target, pos ->
      case p.(target, pos) do
        {:ok, lr, reminder, lpos} ->
          {:ok, f.(lr), reminder, lpos}
        x -> x
      end
    end
  end

  def one_or_many(p, drop \\ false), do: [p, p |> collect] |> sequence(drop)

  @doc "Collects ok-results from parsers into list. Fails if one fails. Drops empty-results on demand"
  @spec sequence( [parser], boolean ) :: parser
  def sequence(checks, drop \\ false) when is_list(checks) do
    if not Enum.any?(checks) do
        &( {:ok, [], &1, &2} )
    else
      &case Enum.reduce_while(checks, {&1, &2, []},   # target, pos, findings
            fn e, acc ->
                {target, pos, findings} = acc
                case (e.(target, pos)) do
                  {:ok, :empty, reminder, lpos} when drop -> {:cont, {reminder, lpos, findings}}
                  {:ok, _ms, reminder, lpos} = lr -> {:cont, {reminder, lpos, [lr |findings]}}
                   _ -> {:halt, :halted}
                end
            end)
        do
            :halted -> {:error, [], &1, &2}
            {reminder, rpos, findings}  -> {:ok, Enum.reverse(findings), reminder, rpos}
            _ -> throw "Shall not happen"
        end #case
    end #if
  end

  def sequence_lift_subresults(checks, drop \\false) do
    sequence_using(checks,
    fn
      {:ok, sr, _,_}, findings when is_list(sr) -> findings ++ sr
      r, findings -> findings ++ List.wrap(r)
    end,
    drop)
  end

  @doc "behaves identical to 'sequence\2'"
  def sequence_standard(checks, drop \\ false) when is_list(checks) do
    sequence_using(checks, fn lr, findings -> findings ++ List.wrap(lr) end, drop)
  end

  @doc "Collects ok-results from parsers into list, using given function. Fails if one fails. Drops empty-results on demand"
  @spec sequence_using( [parser], function, boolean ) :: parser
  def sequence_using(checks, fun, drop \\ false) when is_list(checks) do
    if not Enum.any?(checks) do
        &( {:ok, [], &1, &2} )
    else
      &case Enum.reduce_while(checks, {&1, &2, []},   # target, pos, findings
            fn e, acc ->
                {target, pos, findings} = acc
                case (e.(target, pos)) do
                  {:ok, :empty, reminder, lpos} when drop -> {:cont, {reminder, lpos, findings}}
                  {:ok, _ms, reminder, lpos} = lr -> {:cont, {reminder, lpos, fun.(lr, findings)}}
                    _ -> {:halt, :halted}
                end
            end)
        do
            :halted -> {:error, [], &1, &2}
            {reminder, rpos, findings}  -> {:ok, findings, reminder, rpos}
            _ -> throw "Shall not happen"
        end #case
    end #if
  end

  @doc "Collects consecutive ok-results into list."
  @spec collect(parser) :: parser
  def collect(p) when is_function(p, 2) do
    mapper = fn
      "", pos, res, _fun when is_list(res) ->
        {:ok, Enum.reverse(res), "", pos}

      target, pos, res, fun when is_list(res) and is_bitstring(target) and is_function(fun, 4) ->
        case p.(target, pos) do
          {:ok, lr, reminder, lpos} -> fun.(reminder, lpos, [ lr | res ], fun)
          _ -> {:ok, Enum.reverse(res), target, pos}
        end
    end

    fn target, pos -> mapper.(target, pos, [], mapper) end
  end

  @doc "Parses any character from given string."
  def anyfrom( s ) when is_bitstring(s), do: anyfrom ( to_charlist(s) )
  def anyfrom( sl) when is_list(sl) do
    fn
      "", pos -> {:error, "No input", pos}
      << canditate :: utf8, rem :: binary >>, pos ->
        if Enum.any?( sl, fn e -> e == canditate end) do
          {:ok, canditate, rem, pos + 1}
        else
          {:error, "Expected one of these: #{sl}", pos}
        end
    end
  end

  @doc "Parses a specified string."
  def string( s ) when is_bitstring(s) do
    flen = String.length( s )
    fn target, pos ->
      if String.starts_with?(target, s) do
        {:ok, s, String.slice(target, flen, String.length(target)), flen + pos}
      else
        {:error, "There is no string #{s}.", pos}
      end
    end
  end

  @doc "Parses a specified string."
  def string2( s ) when is_bitstring(s) do
    flen = String.length( s )
    fn
      "", pos -> {:error, "No input", pos}
      target, pos when binary_part(target, 0, flen) == s -> {:ok, s, String.slice(target, flen, String.length(target)), flen + pos}
      _, pos -> {:error, "There is no string #{s}.", pos}
    end
  end

end
