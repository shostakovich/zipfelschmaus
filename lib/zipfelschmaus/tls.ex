defmodule Zipfelschmaus.TLS do
  @moduledoc "TLS client options that verify the server's certificate against the system's CAs."

  @doc "The options for a connection to `host`."
  @spec verify_options(String.t()) :: [:ssl.tls_client_option()]
  def verify_options(host) do
    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(host),
      depth: 99,
      # Mailgun and others present wildcard certificates, which OTP's default check rejects.
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
  end
end
