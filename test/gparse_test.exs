defmodule GparseTest do
  use ExUnit.Case
  doctest Gparse

  import Gparse

  test "greets the world" do
    assert Gparse.hello() == :world
  end

  test "one char from" do
    p = Gparse.anyfrom "abc"
    assert {:ok, 97, "bc", 1} == p.("abc", 0)
    assert {:ok, 98, "c", 1} == p.("bc", 0)
    assert {:error, "Expected one of these: abc", 0} = p.("xbc", 0)
  end

  test "collect characters" do
    p = Gparse.anyfrom "abc"
    c = Gparse.collect p
    assert {:ok, 'aaabbbccc', "FFF", 9} == c.("aaabbbcccFFF", 0)  # result: list
    {:ok, [], "FFF", 0} == c.("FFF", 0)
  end

  test "collect charcters and convert to string" do
    c = Gparse.anyfrom( "abc" )
      |> Gparse.collect |> Gparse.alter_result(fn e -> to_string(e) end)
    assert {:ok, "aaabbbccc", "FFF", 9} == c.("aaabbbcccFFF", 0)  # result: string
  end

  test "parse integer" do
    p = Gparse.pinteger()
    assert {:ok, 123, "", 3} == p.("123", 0)
    assert {:ok, 123, "", 4} == p.("+123", 0)
    assert {:ok,-123, "", 4} == p.("-123", 0)
  end

  test "parse float" do
    p = Gparse.pfloat()
    assert {:ok, 123.0, "", 5} == p.("123.0", 0)
    assert {:ok, 123.12, "", 6} == p.("123.12", 0)
    assert {:ok, -123.12, "abc", 7} == p.("-123.12abc", 0)
  end

  test "between" do
    lc = Gparse.plowercase
    a = Gparse.string "a"
    b = Gparse.string "b"
    axb = Gparse.between(lc, a, b)
    assert {:ok, 105, "", 3} == axb.("aib", 0)
    assert {:ok, 109, "bbb", 3} == axb.("ambbbb", 0)
    #assert {:error, [], "aRb", 0} == axb.("aRb", 0)    # not lowercase
  end

  test "single_or_many_separated" do
    int_or_list_of_ints = single_or_many_separated(pinteger(), string(", "))
    assert {:ok, 123, "", 3} == int_or_list_of_ints.("123",0)
    # assert {:ok, [{:ok, 123, ", 345", 3}, {:ok, 345, "", 8}], "", 8}
    {:ok, [123, 345], "", 8} == int_or_list_of_ints.("123, 345",0)
  end

  test "keep left/right" do
    keep_a = keep_left(string("a"), string("b"))
    assert {:ok, "a", "", 2} == keep_a.("ab", 0)
    assert {:error, "There is no string b.", 1} = keep_a.("aa", 0)

    kb = keep_right(string("a"), string("b"))
    assert {:ok, "b", "", 2} == kb.("ab", 0)
  end

  test "between snd" do
    bab = between(pinteger(), string("a"), string("b"))
    assert {:ok, 123, "", 5} == bab.("a123b", 0)
    assert {:error, "There is no string a.", 0} == bab.("b123b", 0)
  end

  test "nested list" do
    nl = nested_list(pinteger(), string("{"), string("}"), string(", "))
    # assert {:ok, 1, "", 1} ==  nl.("1", 0)      # no brackets -> single
    assert {:ok, [1], "", 3} == nl.("{1}", 0)   # brackets -> list
    assert {:ok, [1, 2, 3], "", 9} == nl.("{1, 2, 3}", 0)
    assert {:ok, [1, [2], 3], "", 11} == nl.("{1, {2}, 3}", 0)  # nesting
    assert {:ok, [1, [2, 4, [[5, 6]]], 3], "", 24} == nl.("{1, {2, 4, {{5, 6}}}, 3}", 0)
    # assert {:error, "There is no string }.", 25} == nl.("{{1, {2, 4, {{5, 6}}}, 3}", 0) # missing close
    assert {:ok, [1, [2, 4, [[5, 6]]], 3], "}", 24} == nl.("{1, {2, 4, {{5, 6}}}, 3}}", 0)   # trailing close
    # assert {:error, [], "{1, {2, 4, {{5, 6}}, 3}", 0} == nl.("{1, {2, 4, {{5, 6}}, 3}", 0)  # wrong bracket
  end

  test "item or list of items" do
    iol = [plowercases(), pinteger()] |> item_or_list_of_items(pwhitespace(), string("{"), string("}"))
    assert {:ok, [12], "", 4} == iol.("{12}", 0)
    assert {:ok, ["a"], "", 3} == iol.("{a}", 0)
    assert {:ok, ["a", ["adam"]], "", 10} == iol.("{a {adam}}", 0)
  end
end
