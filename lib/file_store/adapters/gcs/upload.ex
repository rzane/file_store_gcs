defmodule FileStore.Adapters.GCS.Upload do
  @moduledoc false

  alias FileStore.Adapters.GCS.Client

  defstruct [:id, :bucket, :client, size: 0, start_byte: 0]

  @header "x-guploader-uploadid"
  @chunk_size 5 * 1024 * 1024

  def perform(client, bucket, path, key) do
    with {:ok, %{size: size}} <- File.stat(path),
         {:ok, %{headers: headers}} <- Client.start_upload(client, bucket, key),
         {:ok, id} <- fetch_header(headers, @header) do
      upload = %__MODULE__{id: id, size: size, bucket: bucket, client: client}

      path
      |> File.stream!([], @chunk_size)
      |> reduce_while_ok(upload, &send_chunk(&2, &1))
    end
  end

  defp send_chunk(%__MODULE__{id: id, bucket: bucket, client: client} = upload, chunk) do
    headers = build_headers(upload, chunk)

    with {:ok, resp} <- Client.upload_part(client, bucket, id, chunk, headers),
         {:ok, end_byte} <- fetch_range_end(resp.headers) do
      {:ok, %__MODULE__{upload | start_byte: end_byte + 1}}
    end
  end

  defp build_headers(%__MODULE__{size: size, start_byte: start_byte}, chunk) do
    chunk_size = byte_size(chunk)
    end_byte = start_byte + chunk_size - 1
    range = "bytes #{start_byte}-#{end_byte}/#{size}"
    [{"Content-Length", chunk_size}, {"Content-Range", range}]
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
    |> Enum.find_value(fn {k, _v} -> String.downcase(k) == name end)
    |> case do
      nil -> {:error, {:missing_header, name}}
      value -> {:ok, value}
    end
  end
end
