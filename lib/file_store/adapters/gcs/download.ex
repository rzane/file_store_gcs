defmodule FileStore.Adapters.GCS.Download do
  alias FileStore.Adapters.GCS.Client

  @chunk_size 5 * 1024 * 1024
  @stream_options [max_concurrency: 8, timeout: 60_000]

  def perform(client, bucket, key, io) do
    with {:ok, size} <- get_file_size(client, bucket, key) do
      size
      |> chunk_stream(@chunk_size)
      |> Task.async_stream(&download_chunk(client, bucket, key, io, &1), @stream_options)
      |> Enum.reduce(:ok, &collect_result/2)
    end
  end

  defp collect_result({:error, reason}, {:error, reasons}), do: {:error, reasons ++ [reason]}
  defp collect_result({:error, reason}, :ok), do: {:error, [reason]}
  defp collect_result(:ok, :ok), do: :ok

  defp download_chunk(client, bucket, key, io, {start_byte, end_byte}) do
    headers = [{"range", "bytes=#{start_byte}-#{end_byte}"}]

    case Client.download_chunk(client, bucket, key, headers: headers) do
      {:ok, %HTTPoison.Response{body: body}} ->
        IO.binwrite(io, body)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_file_size(client, bucket, key) do
    case Client.get_object(client, bucket, key) do
      {:ok, %HTTPoison.Response{body: %{"size" => size}}} ->
        {size, _} = Integer.parse(size)
        {:ok, size}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp chunk_stream(file_size, chunk_size) do
    Stream.unfold(0, fn counter ->
      start_byte = counter * chunk_size

      if start_byte >= file_size do
        nil
      else
        end_byte = (counter + 1) * chunk_size

        # byte ranges are inclusive, so we want to remove one. IE, first 500 bytes
        # is range 0-499. Also, we need it bounded by the max size of the file
        end_byte = min(end_byte, file_size) - 1
        {{start_byte, end_byte}, counter + 1}
      end
    end)
  end
end
