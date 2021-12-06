# ProfileUpdater

Updates https://github.com/narze/narze every hour

## Development

```shell
# Install dependencies
mix deps.get

# Prepare ENV
export GH_TOKEN=your_github_personal_token

# Dry run, without committing
mix run -e "ProfileUpdater.run(true)"
cat output.md

# Real run
mix run -e "ProfileUpdater.run"
```
