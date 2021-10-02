defmodule ProfileUpdater do
  @moduledoc """
  Documentation for `ProfileUpdater`.
  """

  def run(dry_run \\ false) do
    access_token = System.get_env("GH_TOKEN")

    client = Tentacat.Client.new(%{access_token: access_token})
    {200, data, _res} = Tentacat.Users.me(client)

    login = data |> get_in(["login"])

    {:ok, sha, old_content, start_line, end_line} = get_current_readme(client, login)
    {:ok, repos_with_topics} = get_repos(client, login)

    {:ok, active_projects} = get_formatted_projects(repos_with_topics, "active-project")
    {:ok, hacktoberfest_projects} = get_formatted_projects(repos_with_topics, "hacktoberfest")

    %DateTime{month: month} = DateTime.utc_now()

    content =
      ["## Active projects"]
      |> Enum.concat(["\n"])
      |> Enum.concat(active_projects)

    content =
      if month == 10 do
        content
        |> Enum.concat(["\n"])
        |> Enum.concat(["## Hacktoberfest projects"])
        |> Enum.concat(["\n"])
        |> Enum.concat(hacktoberfest_projects)
      else
        content
      end

    content =
      content
      |> Enum.join("\n")
      |> Kernel.<>("\n\n")

    content =
      old_content
      |> Enum.slice(0..start_line)
      |> Enum.concat([content])
      |> Enum.concat(old_content |> Enum.slice(end_line..-1))
      |> Enum.join("\n")

    content = Regex.replace(~r/\n(\n)+/, content, "\n\n")

    content_base64 = content |> Base.encode64()

    if dry_run do
      File.write!("output.md", content_base64 |> Base.decode64!())
      IO.puts("Dry-run: output.md written")
      exit(:normal)
    end

    {:ok} = update_readme(client, login, content_base64, sha)

    IO.puts("Done.")
  end

  defp get_current_readme(client, login) do
    {200, file, _res} = Tentacat.Contents.find(client, login, login, "README.md")

    content =
      file |> get_in(["content"]) |> Base.decode64!(ignore: :whitespace) |> String.split("\n")

    start_line =
      content
      |> Enum.find_index(fn l ->
        l == "<!--%%% PROFILE UPDATER (narze/profile-updater) : START %%%-->"
      end)

    end_line =
      content
      |> Enum.find_index(fn l ->
        l == "<!--%%% PROFILE UPDATER (narze/profile-updater) : END %%%-->"
      end)

    if start_line |> is_nil() || end_line |> is_nil() do
      raise "Slot not found!"
    end

    sha = file |> get_in(["sha"])

    {:ok, sha, content, start_line, end_line}
  end

  defp get_repos(client, login) do
    {200, repos, _res} = Tentacat.Repositories.list_users(client, login)

    repos_with_topics =
      repos
      |> Enum.map(fn repo ->
        %{
          name: get_in(repo, ["name"]),
          url: get_in(repo, ["html_url"]),
          topics: get_in(repo, ["topics"])
        }
      end)
      |> Enum.filter(fn r -> length(get_in(r, [:topics])) > 0 end)

    {:ok, repos_with_topics}
  end

  defp get_formatted_projects(repos, topic) do
    repos_with_topic =
      repos
      |> Enum.filter(fn r -> r |> get_in([:topics]) |> Enum.member?(topic) end)

    projects =
      repos_with_topic
      |> Enum.map(fn r ->
        name = get_in(r, [:name])
        url = get_in(r, [:url])
        "- [#{name}](#{url})"
      end)

    {:ok, projects}
  end

  defp update_readme(client, login, content_base64, sha) do
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

    {200, _updated_content, _res} =
      Tentacat.Contents.update(client, login, login, "README.md", body)

    {:ok}
  end
end
