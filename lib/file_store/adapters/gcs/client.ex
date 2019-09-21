defmodule FileStore.Adapters.GCS.Client do
  @moduledoc false

  defstruct body: "",
            path: "/",
            query: [],
            headers: [],
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

  def upload_part(client, bucket, upload_id, body, headers) do
    client
    |> put_path(objects_path(bucket))
    |> put_query(uploadType: "resumable", upload_id: upload_id)
    |> put_headers(headers)
    |> put_body(body)
    |> request(:put)
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

  defp put_headers(client, headers) do
    %__MODULE__{client | headers: client.headers ++ headers}
  end

  defp request(%__MODULE__{body: body} = client, method) do
    url = build_url(client)

    with {:ok, headers} <- build_headers(client),
         {:ok, resp} <- HTTPoison.request(method, url, body, headers),
         do: transform(resp)
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

  defp transform(%{status_code: code} = resp) when code in 200..299, do: {:ok, resp}
  defp transform(resp), do: {:error, resp}
end
