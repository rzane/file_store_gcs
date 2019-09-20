defmodule FileStore.Adapters.GCS.Test do
  use ExUnit.Case
  alias FileStore.Adapters.GCS, as: Adapter

  @bucket "my-private-bucket-for-upload"
  @key "test"
  @content "hello world"
  @path "test/fixtures/test.mp4"

  @store FileStore.new(adapter: Adapter, bucket: @bucket)

  test "write/3" do
    assert :ok = Adapter.write(@store, @key, @content)
  end

  test "upload/3" do
    assert {:ok, data} = Adapter.upload(@store, @path, @key)
    assert data == %{}
  end
end
