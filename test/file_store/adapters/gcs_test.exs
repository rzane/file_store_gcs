defmodule FileStore.Adapters.GCSTest do
  use ExUnit.Case
  alias FileStore.Adapters.GCS, as: Adapter

  @key "test"
  @content "hello world"
  @path "test/fixtures/test.txt"
  @dest Path.join(System.tmp_dir!(), "download.txt")

  @config Application.fetch_env!(:file_store_gcs, :test)
  @store FileStore.new(@config)

  test "write/3" do
    assert :ok = Adapter.write(@store, @key, @content)
  end

  test "upload/3" do
    assert :ok = Adapter.upload(@store, @path, @key)
  end

  test "download/3" do
    assert :ok = Adapter.upload(@store, @path, @key)
    assert :ok = Adapter.download(@store, @key, @dest)
    assert File.exists?(@dest)
  end
end
