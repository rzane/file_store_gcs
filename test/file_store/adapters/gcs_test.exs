defmodule FileStore.Adapters.GCSTest do
  use FileStore.AdapterCase

  alias GoogleApi.Storage.V1.Connection
  alias GoogleApi.Storage.V1.Api.Objects

  @bucket "file-store"

  setup do
    purge_bucket()
    [store: FileStore.Adapters.GCS.new(bucket: @bucket)]
  end

  defp purge_bucket do
    connection = Connection.new()
    {:ok, list} = Objects.storage_objects_list(connection, @bucket)

    for object <- list.items do
      {:ok, _} = Objects.storage_objects_delete(connection, @bucket, object.name)
    end
  end
end
