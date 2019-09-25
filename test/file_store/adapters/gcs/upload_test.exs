defmodule FileStore.Adapters.GCS.UploadTest do
  use ExUnit.Case
  alias FileStore.Adapters.GCS.Client
  alias FileStore.Adapters.GCS.Upload

  @config Application.fetch_env!(:file_store_gcs, :test)
  @client Client.new(@config)
  @bucket Keyword.fetch!(@config, :bucket)

  @key "gcs-upload-test"
  @path "test/fixtures/test.mp4"
  @size 10498677
  @checksum "798ce2689035bc7ed07c1f9bf75f754c"

  test "uploading a file" do
    assert {:ok, stat} = Upload.perform(@client, @bucket, @path, @key)
    assert stat.key == @key
    assert stat.size == @size
    assert stat.etag == @checksum
  end

  test "gracefully handles %File.Error{}" do
    assert {:error, :enoent} = Upload.perform(@client, @bucket, "foo/bar.txt", @key)
  end
end
