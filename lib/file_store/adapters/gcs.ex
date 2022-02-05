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
    alias GoogleApi.Storage.V1.Api.Objects
    alias GoogleApi.Storage.V1.Model

    def write(store, key, content, opts \\ []) do
      connection = build_connection(store)

      metadata = %Model.Object{
        name: key,
        contentDisposition: opts[:disposition],
        contentType: opts[:content_type]
      }

      with {:ok, _} <-
             Objects.storage_objects_insert_iodata(
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
             Objects.storage_objects_get(connection, store.bucket, key, alt: "media"),
           do: {:ok, body}
    end

    def upload(_store, _source, _key), do: {:error, :unsupported}
    def download(_store, _key, _destination), do: {:error, :unsupported}

    def stat(store, key) do
      connection = build_connection(store)

      with {:ok, object} <- Objects.storage_objects_get(connection, store.bucket, key) do
        {:ok,
         %FileStore.Stat{
           key: key,
           type: object.contentType,
           etag: parse_etag(object.md5Hash),
           size: String.to_integer(object.size)
         }}
      end
    end

    def delete(store, key) do
      connection = build_connection(store)

      case Objects.storage_objects_delete(connection, store.bucket, key) do
        {:ok, _} -> :ok
        {:error, %{status: 404}} -> :ok
        {:error, response} -> {:error, response}
      end
    end

    def delete_all(_store, _opts \\ []), do: {:error, :unsupported}
    def copy(_store, _src, _dest), do: {:error, :unsupported}
    def rename(_store, _src, _dest), do: {:error, :unsupported}
    def get_public_url(_store, key, _opts \\ []), do: key
    def get_signed_url(_store, _key, _opts \\ []), do: {:error, :unsupported}

    # FIXME: Support listing nested keys
    def list!(store, opts \\ []) do
      opts = Keyword.take(opts, [:prefix])

      Stream.resource(
        fn -> nil end,
        &do_list!(store, &1, opts),
        fn _ -> nil end
      )
      |> Stream.map(& &1.name)
    end

    defp do_list!(_store, :halt, _opts) do
      {:halt, nil}
    end

    defp do_list!(store, page_token, opts) do
      opts = Keyword.put(opts, :pageToken, page_token)

      store
      |> build_connection()
      |> Objects.storage_objects_list(store.bucket, opts)
      |> case do
        {:ok, %Model.Objects{items: items, nextPageToken: nil}} ->
          {items, :halt}

        {:ok, %Model.Objects{items: items, nextPageToken: next_page_token}} ->
          {items, next_page_token}

        {:error, response} ->
          # FIXME: Nicer error handling
          raise "Failed to retrieve object list: #{inspect(response)}"
      end
    end

    defp parse_etag(md5hash) do
      md5hash |> Base.decode64!() |> Base.encode16() |> String.downcase()
    end

    # FIXME: Support authentication via goth
    # FIXME: Figure out how to provide URL at runtime
    defp build_connection(_store), do: Connection.new()
  end
end
