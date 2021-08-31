defmodule ProfileUpdater do
  @moduledoc """
  Documentation for `ProfileUpdater`.
  """

  @doc """
  Hello world.

  """
  def hello(access_token) do
    client = Tentacat.Client.new(%{access_token: access_token})
    {200, data, _res} = Tentacat.Users.find(client, "narze")

    # Get current sha of readme
    {200, file, _res} = Tentacat.Contents.find(client, "narze", "profile-updater", "README.md")
    sha = file |> get_in(["sha"])

    # Update readme
    username = data |> get_in(["login"])
    follower_count = data |> get_in(["followers"])

    content =
      ["# ProfileUpdater", "My name is #{username}, and I have #{follower_count} followers"]
      |> Enum.join("\n\n")
      |> Base.encode64()

    body = %{
      "message" => "Update README.md",
      "content" => content,
      "sha" => sha,
      "branch" => "main"
    }

    Tentacat.Contents.update(client, "narze", "profile-updater", "README.md", body)
  end
end
