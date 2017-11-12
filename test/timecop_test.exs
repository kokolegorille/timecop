defmodule TimecopTest do
  use ExUnit.Case
  doctest Timecop

  test "greets the world" do
    assert Timecop.hello() == :world
  end
end
