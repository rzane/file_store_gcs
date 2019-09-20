defmodule FileStore.Adapters.GCS.Request do
  @moduledoc false

  @base_url "https://www.googleapis.com/"
  @scope "https://www.googleapis.com/auth/devstorage.read_write"

  defstruct [:store, body: "", path: "/", query: []]

  def new(store) do
    %__MODULE__{store: store}
  end

  def put_path(request, path) do
    %__MODULE__{request | path: path}
  end

  def put_body(request, body) do
    %__MODULE__{request | body: body}
  end

  def put_query(request, query) do
    %__MODULE__{request | query: Keyword.merge(request.query, query)}
  end

  def to_url(%__MODULE__{path: path, query: query}) do
    @base_url
    |> URI.parse()
    |> Map.put(:path, path)
    |> Map.put(:query, URI.encode_query(query))
    |> URI.to_string()
  end

  def ok(request) do
    case call(request) do
      {:ok, _resp} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def call(%__MODULE__{body: body} = request) do
    with {:ok, headers} <- get_headers(request) do
      request |> to_url() |> HTTPoison.post(body, headers)
    end
  end

  defp get_headers(_request) do
    with {:ok, %{token: token}} <- Goth.Token.for_scope(@scope) do
      {:ok, [{"authorization", "Bearer #{token}"}]}
    end
  end
end
