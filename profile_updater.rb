require 'bundler/setup'

require 'octokit'
require 'base64'
require 'date'
require 'debug'

# Code is converted from Elixir to Ruby so it's a bit messy

module ProfileUpdater
  def self.run(dry_run: false)
    puts "Starting... #{dry_run ? '(dry-run)' : ''}"
    access_token = ENV.fetch('GH_TOKEN')

    client = Octokit::Client.new(access_token: access_token)
    client.auto_paginate = true

    data = client.user
    login = data[:login]

    sha, old_content, start_line, end_line = get_current_readme(client, login)
    repos_with_topics = get_repos(client, login)
    manoonchai_repos = get_repos(client, 'Manoonchai')
    all_repos = repos_with_topics + manoonchai_repos

    puts "Found #{all_repos.length} repos"

    active_projects = get_projects(all_repos, 'active-project')
    hacktoberfest_projects = get_projects(all_repos, 'hacktoberfest')
    hacktoberfest_projects = count_projects_pull_requests(client, hacktoberfest_projects)

    formatted_active_projects = format_projects(active_projects)
    formatted_hacktoberfest_projects = format_projects(hacktoberfest_projects, true)

    pr_data = get_merged_pr_count(client)
    merged_prs_count = pr_data[:total_count]

    now = DateTime.now
    month = now.month
    day = now.day

    content = []
    hacktoberfest_content = [
      "## Hacktoberfest projects (#{merged_prs_count} PRs merged!)\n\n",
      "[What is Hacktoberfest?](https://hacktoberfest.digitalocean.com)\n"
    ]
    hacktoberfest_content << formatted_hacktoberfest_projects.join("\n")

    is_hacktoberfest = (month == 10) || (month == 11 && day <= 7)

    content =
      if is_hacktoberfest
        hacktoberfest_content + content
      else
        ["<details><summary>Hacktoberfest 2023</summary>\n"] + hacktoberfest_content + ["</details>\n"] + content
      end

    content << "<details><summary><strong>Active projects</strong></summary>\n"
    content << formatted_active_projects.join("\n")
    content << "</details>\n"

    content = content.join("\n\n")
    content += "\n\n"

    content = old_content[0..start_line] + [content] + old_content[end_line..-1]

    content = content.map { |line| line.force_encoding('UTF-8') }.join("\n")

    content = content.gsub(/\n(\n)+/, "\n\n")

    content_base64 = Base64.strict_encode64(content)

    if dry_run
      File.write("output.md", Base64.strict_decode64(content_base64))
      puts "Dry-run: output.md written"
      exit(0)
    end

    update_readme(client, login, content, sha)

    puts "Done."
  end

  def self.get_current_readme(client, login)
    file = client.contents("#{login}/#{login}", path: 'README.md')
    content = Base64.decode64(file[:content]).split("\n")

    start_line = content.index("<!--%%% PROFILE UPDATER (narze/profile-updater) : START %%%-->")
    end_line = content.index("<!--%%% PROFILE UPDATER (narze/profile-updater) : END %%%-->")

    raise "Slot not found!" if start_line.nil? || end_line.nil?

    sha = file[:sha]

    [sha, content, start_line, end_line]
  end

  def self.get_repos(client, login)
    repos = client.repositories(login, )

    repos_with_topics = repos.select { |repo| !repo[:topics].empty? }

    repos_with_topics
  end

  def self.count_projects_pull_requests(client, repos)
    repos.map do |p|
      pr_count = count_open_pull_requests(client, p[:owner][:login], p[:name])
      p.to_h.merge(pr_count: pr_count)
    end
  end

  def self.count_open_pull_requests(client, org, name)
    pull_requests = client.pulls("#{org}/#{name}")
    pull_requests.length
  end

  def self.get_projects(repos, topic)
    repos.select { |r| r[:topics].include?(topic) }
  end

  def self.format_projects(repos, with_stats = false)
    repos.map do |r|
      name = get_repo_nickname(r[:name])
      url = r[:html_url]
      pr_count = r[:pr_count] || 0
      issues_count = r[:open_issues_count] - pr_count

      stats = if with_stats
                stats_arr = []
                stats_arr << "[#{pr_count} PRs](#{url}/pulls)" if pr_count > 0
                stats_arr << "[#{issues_count} Issues](#{url}/issues)" if issues_count > 0
                stats_arr.join(' / ')
              else
                ''
              end

      stats != '' ? "- [#{name}](#{url}) (#{stats})" : "- [#{name}](#{url})"
    end
  end

  def self.get_repo_nickname(name)
    nicknames = {
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
      "Single-page-svelte" => "Single Page Svelte"
    }

    nicknames[name] || name.capitalize
  end

  def self.update_readme(client, login, content_base64, sha)
    body = {
      message: "Update README.md",
      content: content_base64,
      committer: {
        name: "narze's bot",
        email: "notbarze@users.noreply.github.com"
      },
      sha: sha,
      branch: "main"
    }

    client.update_contents(
      "#{login}/#{login}", "README.md", body[:message], body[:sha], body[:content],
      branch: 'main',  # Replace with your target branch
      committer: {
        name: body[:committer][:name],
        email: body[:committer][:email]
      }
    )
  end

  def self.get_merged_pr_count(client)
    client.search_issues('type:pr user:narze is:merged created:2023-10-01..2023-10-31 sort:created')
  end
end

dry_run = ARGV.include?("--dry-run") || ARGV.include?("-N")

ProfileUpdater.run(dry_run: dry_run)
