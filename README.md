# ProfileUpdater

Updates https://github.com/narze/narze periodically

## Development

```shell
# Install dependencies
bundle install

# Prepare ENV
export GH_TOKEN=your_github_personal_token

# Dry run, without committing
ruby profile_updater.rb -N
cat output.md

# Real run, will update README.md and commit
ruby profile_updater.rb
```
