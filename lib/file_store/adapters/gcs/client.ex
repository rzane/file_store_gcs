defmodule FileStore.Adapters.GCS.Client do
  defstruct base_url: "https://www.googleapis.com/",
            scope: "https://www.googleapis.com/auth/devstorage.read_write",
            options: []

  def new(opts) do
    struct(__MODULE__, opts)
  end

  def get_object(client, bucket, key) do
    request(client, :get, "/storage/v1/b/#{encode(bucket)}/o/#{encode(key)}")
  end

  def insert_object(client, bucket, key, content) do
    query = [uploadType: "media", name: key]
    request(client, :post, upload_path(bucket), body: content, query: query)
  end

  def start_upload(client, bucket, key) do
    query = [uploadType: "resumable", name: key]
    request(client, :post, upload_path(bucket), query: query)
  end

  def resume_upload(client, url, body, opts \\ []) do
    request(client, :put, url, Keyword.put(opts, :body, body))
  end

  def download_chunk(client, bucket, key, opts \\ []) do
    request(client, :get, download_path(bucket, key), opts)
  end

  defp download_path(bucket, key) do
    "/download/storage/v1/b/#{encode(bucket)}/o/#{encode(key)}?alt=media"
  end

  defp upload_path(bucket) do
    "/upload/storage/v1/b/#{encode(bucket)}/o"
  end

  defp request(client, method, path, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    query = Keyword.get(opts, :query, [])
    body = Keyword.get(opts, :body, "")
    url = build_url(client.base_url, path, query)

    with {:ok, headers} <- build_headers(client, headers),
         {:ok, resp} <- HTTPoison.request(method, url, body, headers, client.options) do
      normalize(%HTTPoison.Response{resp | body: parse(resp.body)})
    end
  end

  defp build_url(url, path, query) do
    url
    |> URI.merge(path)
    |> URI.merge("?#{URI.encode_query(query)}")
    |> URI.to_string()
  end

  defp build_headers(%{scope: :anonymous}, headers), do: {:ok, headers}

  defp build_headers(%{scope: scope}, headers) do
    with {:ok, %{token: token}} <- Goth.Token.for_scope(scope) do
      {:ok, headers ++ [{"authorization", "Bearer #{token}"}]}
    end
  end

  defp encode(component) do
    URI.encode(component, &URI.char_unreserved?/1)
  end

  defp parse(body) do
    case Jason.decode(body) do
      {:ok, data} -> data
      _error -> body
    end
  end

  defp normalize(%{status_code: code} = resp) when code in 200..399, do: {:ok, resp}
  defp normalize(resp), do: {:error, resp}
end
