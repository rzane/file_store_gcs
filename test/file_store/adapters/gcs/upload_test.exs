defmodule FileStore.Adapters.GCS.UploadTest do
  use ExUnit.Case
  alias FileStore.Adapters.GCS.Client
  alias FileStore.Adapters.GCS.Upload

  @config Application.fetch_env!(:file_store_gcs, :test)
  @client Client.new(@config)
  @bucket Keyword.fetch!(@config, :bucket)
  @key "gcs-upload-test"
  @path "test/fixtures/test.mp4"

  test "uploading a file" do
    assert {:ok, 10498677} = Upload.perform(@client, @bucket, @path, @key)
  end

  test "gracefully handles %File.Error{}" do
    assert {:error, :enoent} = Upload.perform(@client, @bucket, "foo/bar.txt", @key)
  end
end
