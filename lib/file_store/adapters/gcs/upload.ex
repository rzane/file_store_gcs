defmodule FileStore.Adapters.GCS.Upload do
  @moduledoc false

  alias FileStore.Adapters.GCS.Client

  @chunk_size 5 * 1024 * 1024

  def perform(client, bucket, path, key) do
    with {:ok, %{size: size}} <- File.stat(path),
         {:ok, resp} <- Client.start_upload(client, bucket, key),
         {:ok, url} <- fetch_header(resp.headers, "location"),
         {:ok, bytes} <- do_upload(client, url, path, size) do
      {:ok, bytes}
    end
  rescue
    e in [File.Error] -> {:error, e.reason}
  end

  defp do_upload(client, url, path, size) do
    path
    |> File.stream!([], @chunk_size)
    |> Enum.reduce_while({:ok, 0}, fn body, {:ok, start_byte} ->
      opts = [start_byte: start_byte, size: size]

      case Client.resume_upload(client, url, body, opts) do
        {:ok, response} ->
          {:ok, range} = fetch_header(response.headers, "range")
          [_, range_end] = Regex.run(~r"bytes=\d+-(\d+)", range)
          {range_end, _} = Integer.parse(range_end)
          {:cont, {:ok, range_end + 1}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
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
