defmodule FileStore.Adapters.GCS.Signer do
  @moduledoc false

  alias GcsSignedUrl.Client
  alias GcsSignedUrl.Token
  alias GcsSignedUrl.SignBlob.OAuthConfig

  @spec detect_client(term()) :: {:ok, Client.t() | OAuthConfig.t()} | {:error, term}
  def detect_client(goth) do
    case Registry.lookup(Goth.Registry, goth) do
      [{_pid, {%{source: source}, _token}}] -> build_client(goth, source)
      [] -> raise "failed to detect Goth configuration"
    end
  end

  defp build_client(_goth, {:service_account, credentials, _}) do
    {:ok, Client.load(credentials)}
  end

  defp build_client(goth, {:metadata, options}) do
    account = Keyword.get(options, :account, "default")

    with {:ok, %Token{token: token}} <- Goth.fetch(goth) do
      {:ok, %OAuthConfig{service_account: account, access_token: token}}
    end
  end

  @spec sign(term, binary, binary, Keyword.t()) :: {:ok, binary} | {:error, term}
  def sign(client, bucket, key, opts) do
    case GcsSignedUrl.generate_v4(client, bucket, key, opts) do
      signed_url when is_binary(signed_url) -> {:ok, signed_url}
      {:ok, signed_url} -> {:ok, signed_url}
      {:error, reason} -> {:error, reason}
    end
  end
end
