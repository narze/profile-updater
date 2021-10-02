defmodule ProfileUpdater do
  @moduledoc """
  Documentation for `ProfileUpdater`.
  """

  def run do
    access_token = System.get_env("GH_TOKEN")

    client = Tentacat.Client.new(%{access_token: access_token})
    {200, data, _res} = Tentacat.Users.me(client)

    login = data |> get_in(["login"])

    # Get current sha of readme
    {200, file, _res} = Tentacat.Contents.find(client, login, login, "README.md")
    old_content =  file |> get_in(["content"]) |> Base.decode64!(ignore: :whitespace) |> String.split("\n")

    start_line = old_content |> Enum.find_index(fn l -> l == "<!--%%% PROFILE UPDATER (narze/profile-updater) : START %%%-->" end)
    end_line = old_content |> Enum.find_index(fn l -> l == "<!--%%% PROFILE UPDATER (narze/profile-updater) : END %%%-->" end)

    if start_line |> is_nil() || end_line |> is_nil() do
      raise "Slot not found!"
    end

    sha = file |> get_in(["sha"])
    {200, repos, _res} = Tentacat.Repositories.list_users(client, "narze")

    repos_with_topics = repos |> Enum.map(fn repo -> %{name: get_in(repo, ["name"]), url: get_in(repo, ["html_url"]), topics: get_in(repo, ["topics"])} end) |> Enum.filter(fn r -> length(get_in(r, [:topics])) > 0 end)

    repos_tagged_with_active = repos_with_topics |> Enum.filter(fn r -> r |> get_in([:topics]) |> Enum.member?("active-project") end)

    active_projects = repos_tagged_with_active |> Enum.map(fn r ->
      name = get_in(r, [:name])
      url = get_in(r, [:url])
      "- [#{name}](#{url})"
    end)

    repos_tagged_with_hacktoberfest = repos_with_topics |> Enum.filter(fn r -> r |> get_in([:topics]) |> Enum.member?("hacktoberfest") end)

    hacktoberfest_projects = repos_tagged_with_hacktoberfest |> Enum.map(fn r ->
      name = get_in(r, [:name])
      url = get_in(r, [:url])
      "- [#{name}](#{url})"
    end)

    content = ["## Hacktoberfest projects"]
      |> Enum.concat(["\n"])
      |> Enum.concat(hacktoberfest_projects)
      |> Enum.concat(["\n"])
      |> Enum.concat(["## Active projects"])
      |> Enum.concat(["\n"])
      |> Enum.concat(active_projects)
      |> Enum.join("\n")
      |> Kernel.<>("\n\n")

    content = old_content |> Enum.slice(0..start_line) |> Enum.concat([content]) |> Enum.concat(old_content |> Enum.slice(end_line..-1)) |> Enum.join("\n")
    content = Regex.replace(~r/\n(\n)+/, content, "\n\n")

    content_base64 = content |> Base.encode64()

    File.write!("output.md", content_base64 |> Base.decode64!())

    IO.puts(content_base64)

    body = %{
      "message" => "Update README.md",
      "content" => content_base64,
      "committer" => %{
        "name" => "narze's bot",
        "email" => "notbarze@users.noreply.github.com"
      },
      "sha" => sha,
      "branch" => "main"
    }

    {200, updated_content, _res} = Tentacat.Contents.update(client, login, login, "README.md", body)

    IO.inspect(updated_content)

    IO.puts("Done.")
  end
end
