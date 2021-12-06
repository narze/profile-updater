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
    {:ok, manoonchai_repos} = get_repos(client, "Manoonchai")

    all_repos = repos_with_topics |> Enum.concat(manoonchai_repos)

    {:ok, active_projects} = get_projects(all_repos, "active-project")
    {:ok, hacktoberfest_projects} = get_projects(all_repos, "hacktoberfest")

    hacktoberfest_projects = count_projects_pull_requests(client, hacktoberfest_projects)

    {:ok, formatted_active_projects} = format_projects(active_projects)
    {:ok, formatted_hacktoberfest_projects} = format_projects(hacktoberfest_projects, true)

    {200, pr_pages, _res} = Tentacat.Search.issues(client, q: "type:pr user:narze is:merged created:2021-10-01..2021-10-31", sort: "created")
    {200, pr_data, _res}  = pr_pages |> List.first()
    merged_prs_count = pr_data |> get_in(["total_count"])

    %DateTime{month: month, day: day} = DateTime.utc_now()

    content =
      ["## Active projects"]
      |> Enum.concat(["\n"])
      |> Enum.concat(formatted_active_projects)

    content =
      # if month == 10 || (month == 11 && day <= 7) do
        [
          "## Hacktoberfest projects (#{merged_prs_count} PRs merged!)",
          "\n",
          "\n",
          "[What is Hacktoberfest?](https://hacktoberfest.digitalocean.com)"
        ]
        |> Enum.concat(["\n"])
        |> Enum.concat(formatted_hacktoberfest_projects)
        |> Enum.concat(["\n"])
        |> Enum.concat(content)
      # else
      #   content
      # end

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
          org: get_in(repo, ["owner", "login"]),
          url: get_in(repo, ["html_url"]),
          topics: get_in(repo, ["topics"]),
          issues_count: get_in(repo, ["open_issues_count"])
        }
      end)
      |> Enum.filter(fn r -> length(get_in(r, [:topics])) > 0 end)

    {:ok, repos_with_topics}
  end

  defp count_projects_pull_requests(client, repos) do
    repos
    |> Enum.map(fn p ->
      pr_count = count_open_pull_requests(client, p |> get_in([:org]), p |> get_in([:name]))

      p |> Map.put(:pr_count, pr_count)
    end)
  end

  defp count_open_pull_requests(client, org, name) do
    {200, pull_requests, _res} = Tentacat.Pulls.list(client, org, name)

    pull_requests |> length
  end

  defp get_projects(repos, topic) do
    {:ok,
     repos
     |> Enum.filter(fn r -> r |> get_in([:topics]) |> Enum.member?(topic) end)}
  end

  defp format_projects(repos, with_stats \\ false) do
    projects =
      repos
      |> Enum.map(fn r ->
        name = get_in(r, [:name]) |> get_repo_nickname()
        url = get_in(r, [:url])

        pr_count =
          if Map.has_key?(r, :pr_count) do
            get_in(r, [:pr_count])
          else
            0
          end

        issues_count = get_in(r, [:issues_count]) - pr_count

        stats =
          if with_stats do
            []
            |> Enum.concat(
              if pr_count > 0 do
                ["[#{pr_count} PRs](#{url}/pulls)"]
              else
                []
              end
            )
            |> Enum.concat(
              if issues_count > 0 do
                ["[#{issues_count} Issues](#{url}/issues)"]
              else
                []
              end
            )
            |> Enum.join(" / ")
          else
            ""
          end

        if stats != "" do
          "- [#{name}](#{url}) (#{stats})"
        else
          "- [#{name}](#{url})"
        end
      end)

    {:ok, projects}
  end

  defp get_repo_nickname(name) do
    nicknames = %{
      "awesome-cheab-quotes" => "คำคมเฉียบ ๆ",
      "awesome-salim-quotes" => "วาทะสลิ่มสุดเจ๋ง",
      "coffee-to-code" => "Coffee to Code",
      "DaiMai" => "ได้ไหม?",
      "dumb-questions-th" => "คำถามโง่ ๆ",
      "hacktoberfest_ez" => "Hacktoberfest EZ",
      "nunmun" => "นั่นมัน...!",
      "porsor" => "พส.",
      "profile-updater" => "Profile Updater",
      "skoy.js" => "Skoy.js",
      "torpleng" => "ต่อเพลง",
      "toSkoy" => "เว็บแปลงภาษาสก๊อย",
      "THIS_REPO_HAS_3077_STARS" => "THIS REPO HAS 3077 STARS (Banned)",
      "can-i-order-macbook-m1-max-in-thailand-now" => "Can I order MacBook M1 Max in Thailand now?",
      "Awesome-maas" => "Awesome Markdown as a service",
      "Awesome-websites-as-answers" => "Awesome websites as answers",
      "M1-max-excuses" => "M1 Max Excuses",
      "Single-page-svelte" => "Single Page Svelte",
    }

    if Map.has_key?(nicknames, name) do
      nicknames[name]
    else
      name |> String.capitalize()
    end
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
