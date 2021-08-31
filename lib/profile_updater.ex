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

    name = data |> get_in(["name"])
    email = data |> get_in(["email"])
    login = data |> get_in(["login"])
    follower_count = data |> get_in(["followers"])
    following_count = data |> get_in(["following"])

    # Get current sha of readme
    {200, file, _res} = Tentacat.Contents.find(client, login, "profile-updater", "README.md")
    sha = file |> get_in(["sha"])

    # Update readme
    content =
      ["# ProfileUpdater", "My name is #{login}, and I have #{follower_count} followers, I also followed #{following_count} users."]
      |> Enum.join("\n\n")
      |> Base.encode64()

    body = %{
      "message" => "Update README.md",
      "content" => content,
      "committer" => %{
        "name"  => name,
        "email" => email,
      },
      "sha" => sha,
      "branch" => "main"
    }

    Tentacat.Contents.update(client, login, "profile-updater", "README.md", body)
  end
end
