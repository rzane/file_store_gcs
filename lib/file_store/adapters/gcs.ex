defmodule FileStore.Adapters.GCS do
  @enforce_keys [:bucket]
  defstruct [:bucket]

  def new(opts) do
    if is_nil(opts[:bucket]) do
      raise "missing configuration: :bucket"
    end

    struct(__MODULE__, opts)
  end

  defimpl FileStore do
    alias GoogleApi.Storage.V1.Connection
    alias GoogleApi.Storage.V1.Api
    alias GoogleApi.Storage.V1.Model

    def write(store, key, content, opts \\ []) do
      connection = build_connection(store)

      metadata = %Model.Object{
        name: key,
        contentDisposition: opts[:disposition],
        contentType: opts[:content_type]
      }

      with {:ok, _} <-
             Api.Objects.storage_objects_insert_iodata(
               connection,
               store.bucket,
               "multipart",
               metadata,
               content
             ),
           do: :ok
    end

    def read(store, key) do
      connection = build_connection(store)

      with {:ok, %{body: body}} <-
             Api.Objects.storage_objects_get(connection, store.bucket, key, alt: "media"),
           do: {:ok, body}
    end

    # FIXME: Support authentication via goth
    # FIXME: Figure out how to provide URL at runtime
    defp build_connection(_store), do: Connection.new()
  end
end
