defmodule Zipfelschmaus.Users.UserNotifier do
  @moduledoc false
  import Swoosh.Email

  require Logger

  alias Zipfelschmaus.Mailer

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(Application.fetch_env!(:zipfelschmaus, :mail_from))
      |> subject(subject)
      |> text_body(body)

    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        {:ok, email}

      {:error, reason} = error ->
        Logger.error("Mail \"#{subject}\" not delivered: #{inspect(reason)}")
        error
    end
  end

  def deliver_passkey_added(user, passkey) do
    deliver(user.email, "ZipfelSchmaus: neuer Passkey „#{passkey.name}“", """
    Hallo,

    für dein Konto bei ZipfelSchmaus wurde der Passkey „#{passkey.name}“ angelegt.

    Warst du das nicht, melde dich mit einem Anmeldelink an und lösche ihn unter „Ich“.
    """)
  end

  def deliver_login_instructions(user, url) do
    deliver(user.email, "ZipfelSchmaus: Anmeldelink", """
    Hallo,

    mit diesem Link meldest du dich bei ZipfelSchmaus an. Er gilt 15 Minuten und nur einmal:

    #{url}

    Danach kannst du unter „Ich“ einen Passkey anlegen.

    Wenn du das nicht angefordert hast, ignoriere diese Mail.
    """)
  end
end
