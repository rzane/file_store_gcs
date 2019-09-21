defmodule FileStore.Adapters.GCS.Upload do
  alias FileStore.Adapters.GCS.Client

  defstruct [
    :id,
    :key,
    :path,
    :bucket,
    :client,
    total_bytes: 0,
    sent_bytes: 0
  ]

  @header "X-GUploader-UploadID"
  @chunk_size 5 * 1024 * 1024

  def perform(client, bucket, path, key) do
    upload = %__MODULE__{key: key, path: path, bucket: bucket, client: client}

    with {:ok, %{size: total_bytes}} <- File.stat(path),
         {:ok, %{headers: headers}} <- Client.start_upload(client, bucket, key),
         {:ok, id} <- fetch_header(headers, @header) do
      stream_file(%Upload{upload | id: id, total_bytes: total_bytes})
    end
  end

  defp stream_file(%__MODULE__{path: path} = upload) do
    path
    |> File.stream!([], @chunk_size)
    |> reduce_while_ok(upload, &send_chunk/2)
  end

  defp send_chunk(chunk, %__MODULE__{id: id, bucket: bucket, sent_bytes: sent_bytes}) do
    chunk_size = byte_size(chunk)

    headers = [
      {"Content-Length", chunk_size},
      {"Content-Range", "bytes #{sent_bytes}-#{sent_bytes + chunk_size - 1}/#{size}"}
    ]

    with {:ok, resp} <- Client.upload_part(client, bucket, upload_id, chunk, headers) do
      # Use `Range` response header.
      {:ok, %__MODULE__{upload | sent_bytes: sent_bytes + chunk_size}}
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

  defp fetch_header(headers, name) do
    headers
    |> Enum.find_value(fn {k, _v} -> String.downcase(k) == name end)
    |> case do
      nil -> {:error, {:missing_header, name}}
      value -> {:ok, value}
    end
  end
end
