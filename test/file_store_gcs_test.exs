defmodule FileStoreGcsTest do
  use ExUnit.Case
  doctest FileStoreGcs

  test "greets the world" do
    assert FileStoreGcs.hello() == :world
  end
end
