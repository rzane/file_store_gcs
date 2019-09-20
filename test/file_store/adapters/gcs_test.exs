defmodule FileStore.Adapters.GCS.Test do
  use ExUnit.Case
  alias FileStore.Adapters.GCS, as: Adapter

  @bucket "my-private-bucket-for-upload"
  @store FileStore.new(adapter: Adapter, bucket: @bucket)

  test "write/3" do
    assert :ok = Adapter.write(@store, "aaaaaa", "hello world")
  end
end
