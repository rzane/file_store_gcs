defmodule FileStore.Adapters.GCS do
  @behaviour FileStore.Adapter

  alias FileStore.Adapters.GCS.Request

  @impl true
  def write(store, key, content) do
    bucket = store |> get_bucket() |> encode()

    store
    |> Request.new()
    |> Request.put_path("/upload/storage/v1/b/#{bucket}/o")
    |> Request.put_query(uploadType: "media", name: key)
    |> Request.put_body(content)
    |> Request.ok()
  end

  defp encode(component) do
    URI.encode(component, &URI.char_unreserved?/1)
  end

  defp get_bucket(store) do
    case Map.fetch(store.config, :bucket) do
      {:ok, bucket} -> bucket
      :error -> raise "GCS storage expects a `:bucket`"
    end
  end
end
