defmodule FileStore.Adapters.GCSTest do
  use FileStore.AdapterCase

  alias GoogleApi.Storage.V1.Connection
  alias GoogleApi.Storage.V1.Api.Objects
  alias GoogleApi.Storage.V1.Api.Buckets

  @project "project"
  @bucket "file-store"

  setup do
    prepare_bucket()
    [store: FileStore.Adapters.GCS.new(bucket: @bucket)]
  end

  defp prepare_bucket do
    connection = Connection.new()

    {:ok, _bucket} = Buckets.storage_buckets_insert(connection, @project, body: %{name: @bucket})
    {:ok, %{items: objects}} = Objects.storage_objects_list(connection, @bucket)

    for object <- objects do
      {:ok, _} = Objects.storage_objects_delete(connection, @bucket, object.name)
    end
  end
end
