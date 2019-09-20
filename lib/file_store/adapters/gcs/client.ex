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

  def put_path(client, path) do
    %__MODULE__{client | path: path}
  end

  def put_body(client, body) do
    %__MODULE__{client | body: body}
  end

  def put_query(client, query) do
    %__MODULE__{client | query: client.query ++ query}
  end

  def put_headers(client, headers) do
    %__MODULE__{client | headers: client.headers ++ headers}
  end

  def request(%__MODULE__{body: body, headers: headers, scope: scope} = client, method) do
    with {:ok, %{token: token}} <- Goth.Token.for_scope(scope) do
      headers = headers ++ [{"authorization", "Bearer #{token}"}]

      method
      |> HTTPoison.request(build_url(client), body, headers)
      |> process_response()
    end
  end

  defp process_response({:error, resp}), do: {:error, resp}

  defp process_response({:ok, %{status_code: code} = resp})
       when code < 200 or code > 399 do
    {:error, resp}
  end

  defp process_response({:ok, resp}), do: {:ok, resp}

  defp build_url(%__MODULE__{base_url: base_url, path: path, query: query}) do
    base_url
    |> URI.parse()
    |> Map.put(:path, path)
    |> Map.put(:query, URI.encode_query(query))
    |> URI.to_string()
  end

  defp objects_path(bucket) do
    "/upload/storage/v1/b/#{encode(bucket)}/o"
  end

  defp encode(component) do
    URI.encode(component, &URI.char_unreserved?/1)
  end
end
