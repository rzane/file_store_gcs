defmodule FileStore.Adapters.GCSTest do
  use FileStore.AdapterCase

  alias GoogleApi.Storage.V1.Connection
  alias GoogleApi.Storage.V1.Api.Objects
  alias GoogleApi.Storage.V1.Api.Buckets

  @project "project"
  @bucket "file-store"

  setup do
    start_supervised!({Goth, name: FileStore.Goth, source: generate_source()})
    prepare_bucket()
    [store: FileStore.Adapters.GCS.new(bucket: @bucket, goth: FileStore.Goth)]
  end

  defp generate_source do
    {_, private_key} = generate_private_key()
    {:service_account, %{"client_email" => "user@example.com", "private_key" => private_key}, []}
  end

  defp generate_private_key do
    {:rsa, 2048}
    |> JOSE.JWK.generate_key()
    |> JOSE.JWK.to_pem()
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
