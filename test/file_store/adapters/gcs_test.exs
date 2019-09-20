defmodule FileStore.Adapters.GCS.Test do
  use ExUnit.Case
  alias FileStore.Adapters.GCS, as: Adapter

  doctest Adapter

  test "greets the world" do
    assert Adapter.hello() == :world
  end
end
