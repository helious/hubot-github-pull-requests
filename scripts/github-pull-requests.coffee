# Description:
#   A way to list all currently open PRs on GitHub.
#
# Dependencies:
#   "async": "~1.4.2",
#   "bluebird": "~2.10.0",
#   "octonode": ">0.6.0 <0.8.0"
#
# Configuration:
#   GITHUB_PRS_OAUTH_TOKEN = # (Required) A GitHub OAuth token generated from your account.
#   GITHUB_PRS_TEAM_ID = # (Required) The GitHub Team ID returned from GitHub's API.
#   GITHUB_PRS_REPO_OWNER_FILTER = # (Optional) A string that contains the names of users you'd like to filter by. (Helpful when you have a lot of forks on your repos that you don't care about.)
#
# Commands:
#   hubot pr - Returns a list of open PR links from GitHub.
#   hubot prs - Same as "hubot pr".
#
# Author:
#   helious (David Posey)

async = require 'async'
Promise = require 'bluebird'
Octonode = Promise.promisifyAll(require 'octonode')

module.exports = (robot) ->
  robot.respond /(pr|prs)/i, (msg) ->
    getAllRepos = (done) ->
      getReposByPage = (page) ->
        repoIsDesired = (repoOwner) ->
          repoOwners = process.env.GITHUB_PRS_REPO_OWNER_FILTER

          return true unless repoOwners

          repoOwners isnt null and repoOwners.indexOf(repoOwner) > -1

        gitHub.team(process.env.GITHUB_PRS_TEAM_ID)
          .reposAsync(per_page: 100, page: page)
          .then (data) ->
            reposByPage = data[0]

            for repo in reposByPage
              repoOwner = repo.full_name.split('/')[0]

              repos.push repo if repoIsDesired(repoOwner)

            if reposByPage.length is 100
              getReposByPage page + 1
            else
              done()

      getReposByPage 1

    getAllPullRequests = ->
      getPullRequests = (done, repo) ->
        gitHubRepo = gitHub.repo repo
        prs = []

        gitHubRepo
          .prsAsync()
          .then (data) ->
            postToHipChat = (pr) ->
              lastUpdated = (date) ->
                pluralize = (amount, unit) ->
                  if amount
                    "#{ amount } #{ unit }#{ if amount > 1 then 's' else '' }"
                  else
                    ''

                difference = Date.now() - Date.parse(date)
                days = Math.floor difference / 1000 / 60 / 60 / 24
                hours = Math.floor(difference / 1000 / 60 / 60) - 24 * days
                minutes = Math.floor(difference / 1000 / 60) - 24 * 60 * days - 60 * hours
                hasValidTime = "#{ days }#{ hours }#{ minutes }" isnt ''
                timeString = if hasValidTime then "#{ pluralize days, 'day' } #{ pluralize hours, 'hour' } #{ pluralize minutes, 'minute' } ago".trim() else 'just now'

                "last updated #{ timeString }"

              number = pr.number
              url = pr.html_url
              title = pr.title
              updatedAt = pr.updated_at
              user = pr.user.login

              msg.send "/me - #{ repo } - ##{ number } - #{ title } - #{ user } - #{ url } - #{ lastUpdated updatedAt }"
            prs = data[0]

            postToHipChat pr for pr in prs
          .then ->
            done null, prs.length

      parallelifyGetPullRequests = (repo) -> (done) -> getPullRequests(done, repo.full_name)

      parallelGetPullRequests = []

      for repo in repos
        parallelGetPullRequests.push parallelifyGetPullRequests(repo)

      async.parallel parallelGetPullRequests, (err, results) ->
        pullRequestCount = results.reduce (a, b) -> a + b

        isSingular = pullRequestCount is 1

        msg.send "There #{ if isSingular then 'is' else 'are' } #{ pullRequestCount } open Pull Request#{ if isSingular then '.' else 's.' }"
    gitHub = Octonode.client(process.env.GITHUB_PRS_OAUTH_TOKEN)
    repos = []

    getAllRepos getAllPullRequests
