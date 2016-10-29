# Description:
#   A way to list all currently open PRs on GitHub.
#
# Dependencies:
#   "async": "~1.4.2",
#   "bluebird": "~2.10.0",
#   "octonode": "> 0.6.0 < 0.8.0"
#
# Configuration:
#   GITHUB_PRS_OAUTH_TOKEN = # (Required) A GitHub OAuth token generated from your account.
#   GITHUB_PRS_USER = # (Required if GITHUB_PRS_TEAM_ID is not set) A GitHub username.
#   GITHUB_PRS_TEAM_ID = # (Required if GITHUB_PRS_USER is not set) A GitHub Team ID returned from GitHub's API. Takes precedence over GITHUB_PRS_USER.
#   GITHUB_PRS_REPO_OWNER_FILTER = # (Optional) A string that contains the names of users you'd like to filter by. (Helpful when you have a lot of forks on your repos that you don't care about.)
#
# Commands:
#   hubot pr - Returns a list of open PR links from GitHub.
#   hubot prs - Same as "hubot pr".
#
# Author:
#   helious (David Posey)
#   davedash (Dave Dash)

async = require 'async'
Promise = require 'bluebird'
Octonode = Promise.promisifyAll(require 'octonode')
fs = require 'fs'
HubotCron = require 'hubot-cronjob'

REMINDER_CRON = '18 9,12,17,18 * * 1-5'
REMINDER_TIMEZONE = 'America/Los_Angeles'

# default - running from the root of hubot/ when using external script
gitmap = process.env.GITMAP_FILE_PATH or './data/gitmap.json'
try
  gitdata = fs.readFileSync gitmap, 'utf-8'
  if gitdata
    gitmapData = JSON.parse(gitdata)
catch error
  console.log('Unable to read or load file', error)

createUserMap = ->
  mapGit = {}
  mapGit[gitmapData.gitmap[i].github] = gitmapData.gitmap[i].slack for i in [0...gitmapData.gitmap.length]
  return mapGit

SLACK_USER_MAP = createUserMap()


getAllRepos = (gitHub, repos, done) ->
  getReposByPage = (page) ->
    userGitHub = if process.env.GITHUB_PRS_TEAM_ID?
      gitHub.team process.env.GITHUB_PRS_TEAM_ID
    else
      gitHub.user process.env.GITHUB_PRS_USER

    repoIsDesired = (repoOwner) ->
      repoOwners = process.env.GITHUB_PRS_REPO_OWNER_FILTER

      return true unless repoOwners

      repoOwners? and repoOwners.indexOf(repoOwner) > -1

    userGitHub
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


addToDigest = (pr, digest) ->
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
  people = user

  if !digest['Unassigned']
    digest['Unassigned'] = []

  if pr.assignee
    people = "#{ user }->#{ pr.assignee.login }"
    slackName = SLACK_USER_MAP[pr.assignee.login]
    if slackName
      if !digest[slackName]
        digest[slackName] = []
      digest[slackName].push ":octocat: #{ title } - #{ people } - #{ url } - #{ lastUpdated updatedAt }\n"
  else
    people = "#{ user } (Unassigned)"
    digest['Unassigned'].push ":octocat: #{ title } - #{ people } - #{ url } - #{ lastUpdated updatedAt }\n"


getAllPullRequests = (gitHub, repos, bot) ->
  digest = {}

  getPullRequests = (done, repo) ->
    gitHubRepo = gitHub.repo repo
    prs = []

    gitHubRepo
      .prsAsync()
      .then (data) ->
        prs = data[0]
        addToDigest(pr, digest) for pr in prs
      .then ->
        done null, prs.length

  parallelifyGetPullRequests = (repo) -> (done) -> getPullRequests(done, repo.full_name)

  parallelGetPullRequests = []

  for repo in repos
    parallelGetPullRequests.push parallelifyGetPullRequests(repo)

  async.parallel parallelGetPullRequests, (err, results) ->
    for key, value of digest
      if key != 'Unassigned'
        prDashboard = "#{value.length} open pull request reviews for #{key}:\n"
        for i of value
          prDashboard += value[i]
        try
          bot.send {room: key}, prDashboard
        catch error
          console.log("Unable to send PR reminder to user #{key}." )

    console.log "#{digest['Unassigned'].length} unassigned PRs."

module.exports = (robot) ->
  gitHub = if process.env.GITHUB_PRS_GHE_API_URL?
    Octonode.client(process.env.GITHUB_PRS_OAUTH_TOKEN, hostname: process.env.GITHUB_PRS_GHE_API_URL)
  else
    Octonode.client(process.env.GITHUB_PRS_OAUTH_TOKEN)

  repos = []

  messageAll = -> getAllRepos gitHub, repos, ->
    getAllPullRequests gitHub, repos, robot

  new HubotCron REMINDER_CRON, REMINDER_TIMEZONE, messageAll

  robot.respond /(pr\b|prs)/i, (msg) ->
    getAllRepos gitHub, repos, ->
      getAllPullRequests gitHub, repos, robot
