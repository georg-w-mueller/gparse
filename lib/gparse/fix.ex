defmodule Gparse.Fix do

  # Y combinator
  def fix(f) do
    (fn z ->
        z.(z)
    end).(fn x ->
        f.(fn a -> (x.(x)).(a) end)
    end)
  end

  def fix2(f) do
    (fn z ->
        z.(z)
    end).(fn x ->
        f.(fn a,b -> (x.(x)).(a, b) end)
    end)
  end

  # fc = fn factorial ->
  #   fn
  #       0 -> 0
  #       1 -> 1
  #       number -> number * factorial.(number - 1)
  #   end
  # end

  #fac = fix(fc)
  #fac.(6)

  defp pred(r) when is_function(r,2), do: r.(:yield, nil)
  defp pred(r), do: r

  def fstore, do: fstore([])
  def fstore(l) when is_list(l) do
    fn
      :store, v -> fstore( [v | l] )
      :yield, _ -> l |> Enum.reverse |>
        case do
          [f, s] when is_function(f) and is_function(s) ->
            f.(:yield, nil) ++ s.(:yield, nil)
          [f, s] when is_function(f) ->
            f.(:yield, nil) ++ [s]
          [f, s] when is_function(s) ->
            [f | s.(:yield, nil)]
          #[f, s, []] -> [f, s]
          #_ -> raise "fstore.yield: Shall not happen"
          x -> x
        end
    end
  end
end # Gparse.Fix
