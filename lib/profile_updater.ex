defmodule ProfileUpdater do
  @moduledoc """
  Documentation for `ProfileUpdater`.
  """

  @doc """
  Hello world.

  """
  def hello(access_token) do
    client = Tentacat.Client.new(%{access_token: access_token})
    {200, data, _res} = Tentacat.Users.me(client)

    login = data |> get_in(["login"])

    # Get current sha of readme
    {200, file, _res} = Tentacat.Contents.find(client, login, login, "README.md")
    sha = file |> get_in(["sha"])

    # Update readme
    {:ok, template_file} = File.read("template.md")

    content =
      template_file
      |> Base.encode64()

    IO.puts(content)

    body = %{
      "message" => "Update README.md",
      "content" => content,
      "committer" => %{
        "name" => "narze's bot",
        "email" => "notbarze@users.noreply.github.com"
      },
      "sha" => sha,
      "branch" => "main"
    }

    {200, content, _res} = Tentacat.Contents.update(client, login, login, "README.md", body)

    IO.inspect(content)

    IO.puts("Done.")
  end
end
