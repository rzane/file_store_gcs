defmodule FileStore.Adapters.GCS.Upload do
  alias FileStore.Adapters.GCS.Client

  @header "X-GUploader-UploadID"
  @chunk_size 5 * 1024 * 1024

  def perform(client, bucket, path, key) do
    with {:ok, %{size: size}} <- File.stat(path),
         {:ok, %{headers: headers}} <- Client.start_upload(client, bucket, key),
         {:ok, upload_id} <- headers |> Enum.into(%{}) |> Map.fetch(@header) do
      path
      |> File.stream!([], @chunk_size)
      |> Enum.reduce(0, fn chunk, offset ->
        chunk_size = byte_size(chunk)
        headers = [
          {"Content-Length", chunk_size},
          {"Content-Range", "bytes #{offset}-#{offset + chunk_size - 1}/#{size}"}
        ]

        case Client.upload_part(client, bucket, upload_id, chunk, headers) do
          {:ok, resp} ->
            IO.puts "==> SUCCESS"
            IO.inspect(resp)

          {:error, resp} ->
            IO.puts "==> ERROR"
            IO.inspect(resp)
        end

        # FIXME: Do not assume GCS got all bytes. Parse the `Range` header.
        offset + chunk_size
      end)
    end
  end
end
