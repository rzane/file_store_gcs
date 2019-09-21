defmodule FileStore.Adapters.GCS.Client do
  @moduledoc false

  defstruct body: "",
            path: "/",
            query: [],
            headers: [],
            options: [],
            base_url: "https://www.googleapis.com/",
            scope: "https://www.googleapis.com/auth/devstorage.read_write"

  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  def write(client, bucket, key, content) do
    client
    |> put_path(objects_path(bucket))
    |> put_query(uploadType: "media", name: key)
    |> put_body(content)
    |> request(:post)
  end

  def start_upload(client, bucket, key) do
    client
    |> put_path(objects_path(bucket))
    |> put_query(uploadType: "resumable", name: key)
    |> request(:post)
  end

  def resume_upload(%__MODULE__{options: options} = client, url, body, opts \\ []) do
    chunk_size = byte_size(body)
    size = Keyword.get(opts, :size, "*")
    start_byte = Keyword.get(opts, :start_byte, 0)
    end_byte = start_byte + chunk_size - 1

    upload_headers = [
      {"Content-Length", chunk_size},
      {"Content-Range", "bytes #{start_byte}-#{end_byte}/#{size}"}
    ]

    with {:ok, headers} <- build_headers(client) do
      HTTPoison.put(url, body, headers ++ upload_headers, options)
    end
  end

  defp put_path(client, path) do
    %__MODULE__{client | path: path}
  end

  defp put_body(client, body) do
    %__MODULE__{client | body: body}
  end

  defp put_query(client, query) do
    %__MODULE__{client | query: client.query ++ query}
  end

  defp request(%__MODULE__{body: body, options: options} = client, method) do
    url = build_url(client)

    with {:ok, headers} <- build_headers(client) do
      method
      |> HTTPoison.request(url, body, headers, options)
      |> normalize()
    end
  end

  defp build_url(%__MODULE__{base_url: base_url, path: path, query: query}) do
    base_url
    |> URI.parse()
    |> Map.put(:path, path)
    |> Map.put(:query, URI.encode_query(query))
    |> URI.to_string()
  end

  defp build_headers(%__MODULE__{scope: :anonymous, headers: headers}) do
    {:ok, headers}
  end

  defp build_headers(%__MODULE__{scope: scope, headers: headers}) do
    with {:ok, %{token: token}} <- Goth.Token.for_scope(scope) do
      {:ok, headers ++ [{"authorization", "Bearer #{token}"}]}
    end
  end

  defp objects_path(bucket) do
    "/upload/storage/v1/b/#{encode(bucket)}/o"
  end

  defp encode(component) do
    URI.encode(component, &URI.char_unreserved?/1)
  end

  defp normalize({:ok, %{status_code: code} = resp}) when code in 200..299, do: {:ok, resp}
  defp normalize({_, resp}), do: {:error, resp}
end
