defmodule FileStore.Adapters.GCS do
  @behaviour FileStore.Adapter

  alias FileStore.Adapters.GCS.Client
  alias FileStore.Adapters.GCS.Upload
  alias FileStore.Adapters.GCS.Download

  @impl true
  def write(store, key, content) do
    store
    |> build_client()
    |> Client.insert_object(get_bucket(store), key, content)
    |> case do
      {:ok, _} -> :ok
      {:error, resp} -> {:error, resp}
    end
  end

  @impl true
  def upload(store, path, key) do
    store
    |> build_client()
    |> Upload.perform(get_bucket(store), path, key)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def download(store, key, dest) do
    store
    |> build_client()
    |> Download.perform(get_bucket(store), key, dest)
  end

  defp build_client(store) do
    store.config
    |> Map.take([:base_url, :scope, :options])
    |> Map.to_list()
    |> Client.new()
  end

  defp get_bucket(store) do
    case Map.fetch(store.config, :bucket) do
      {:ok, bucket} -> bucket
      :error -> raise "GCS storage expects a `:bucket`"
    end
  end
end
