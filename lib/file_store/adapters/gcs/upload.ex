defmodule FileStore.Adapters.GCS.Upload do
  @moduledoc false

  alias FileStore.Stat
  alias FileStore.Adapters.GCS.Client

  @chunk_size 5 * 1024 * 1024

  def perform(client, bucket, path, key) do
    with {:ok, %{size: size}} <- File.stat(path),
         {:ok, resp} <- Client.start_upload(client, bucket, key),
         {:ok, url} <- fetch_header(resp.headers, "location"),
         stat <- %Stat{key: key, size: size},
         {:ok, {_bytes, stat}} <- do_upload(client, url, path, stat) do
      {:ok, stat}
    end
  rescue
    e in [File.Error] -> {:error, e.reason}
  end

  defp do_upload(client, url, path, stat) do
    path
    |> File.stream!([], @chunk_size)
    |> Enum.reduce_while({:ok, {0, stat}}, fn body, {:ok, {offset, stat}} ->
      case Client.resume_upload(client, url, body, offset: offset, size: stat.size) do
        {:ok, response} ->
          etag = parse_etag(response)
          offset = parse_offset(response)
          {:cont, {:ok, {offset, %Stat{stat | etag: etag}}}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp parse_offset(%HTTPoison.Response{headers: headers}) do
    {:ok, range} = fetch_header(headers, "range")
    [_, range_end] = Regex.run(~r"bytes=\d+-(\d+)", range)
    {range_end, _} = Integer.parse(range_end)
    range_end + 1
  end

  defp parse_etag(%HTTPoison.Response{body: %{"md5hash" => md5hash}}) do
    md5hash |> Base.decode64!() |> Base.encode16() |> String.downcase()
  end

  defp fetch_header(headers, name) do
    headers
    |> Enum.find(fn {key, _} -> String.downcase(key) == name end)
    |> case do
      {_, value} -> {:ok, value}
      nil -> {:error, {:missing_header, name}}
    end
  end
end
