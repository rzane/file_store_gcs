defmodule FileStore.Adapters.GCS.Upload do
  @moduledoc false

  alias FileStore.Adapters.GCS.Client

  @chunk_size 5 * 1024 * 1024

  def perform(client, bucket, path, key) do
    with {:ok, %{size: size}} <- File.stat(path),
         {:ok, resp} <- Client.start_upload(client, bucket, key),
         {:ok, url} <- fetch_header(resp.headers, "location") do
      path
      |> File.stream!([], @chunk_size)
      |> reduce_while_ok(0, fn body, start_byte ->
        opts = [start_byte: start_byte, size: size]

        with {:ok, resp} <- Client.resume_upload(client, url, body, opts),
             {:ok, end_byte} <- fetch_range_end(resp.headers) do
          {:ok, end_byte + 1}
        end
      end)
    end
  end

  defp reduce_while_ok(enumerable, initial, fun) do
    Enum.reduce_while(enumerable, {:ok, initial}, fn value, {:ok, acc} ->
      case fun.(value, acc) do
        {:ok, next_value} -> {:cont, {:ok, next_value}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp fetch_range_end(headers) do
    with {:ok, range} <- fetch_header(headers, "range") do
      {end_byte, _} =
        range
        |> String.split("-")
        |> Enum.at(1)
        |> Integer.parse()

      {:ok, end_byte}
    end
  end

  defp fetch_header(headers, name) do
    headers
    |> Enum.find(fn {key, _} -> String.downcase(key) == name end)
    |> case do
      nil -> {:error, {:missing_header, name}}
      {_, value} -> {:ok, value}
    end
  end
end
