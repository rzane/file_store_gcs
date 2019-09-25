defmodule FileStore.Adapters.GCS.UploadTest do
  use ExUnit.Case
  alias FileStore.Adapters.GCS.Client
  alias FileStore.Adapters.GCS.Upload

  @config Application.fetch_env!(:file_store_gcs, :test)
  @client Client.new(@config)
  @bucket Keyword.fetch!(@config, :bucket)
  @path "test/fixtures/test.mp4"
  @key "gcs-upload-test"

  test "perform/4" do
    assert {:ok, 10498677} = Upload.perform(@client, @bucket, @path, @key)
  end
end
