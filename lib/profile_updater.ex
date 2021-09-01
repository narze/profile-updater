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
    {200, repos, _res} = Tentacat.Repositories.list_users(client, "narze")

    repos_with_topics = repos |> Enum.map(fn repo -> %{name: get_in(repo, ["name"]), url: get_in(repo, ["html_url"]), topics: get_in(repo, ["topics"])} end) |> Enum.filter(fn r -> length(get_in(r, [:topics])) > 0 end)

    repos_tagged_with_active = repos_with_topics |> Enum.filter(fn r -> r |> get_in([:topics]) |> Enum.member?("active-project") end)

    active_projects = repos_tagged_with_active |> Enum.map(fn r ->
      name = get_in(r, [:name])
      url = get_in(r, [:url])
      "- [#{name}](#{url})"
    end)

    # Update readme
    {:ok, template_file} = File.read("template.md")

    content = ["Active projects:"]
      |> Enum.concat(["\n"])
      |> Enum.concat(active_projects)
      |> Enum.join("\n")
      |> Kernel.<>("\n\n")
      |> Kernel.<>(template_file)
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
