# hubot-github-pull-requests [![npm version](https://badge.fury.io/js/hubot-github-pull-requests.svg)](https://badge.fury.io/js/hubot-github-pull-requests)

A script for Hubot to show open pull requests on GitHub for repos you own/have access to and care about.


## Install

Add the node package to the hubot dependencies in `package.json`

```bash
$ npm install hubot-github-pull-requests --save
```

Add hubot-github-pull-requests to `external-scripts.json`

```javascript
["hubot-github-pull-requests"]
```


## Usage

```bash
> hubot pr
> # List of Pull Requests from GitHub...
> hubot prs
> # List of Pull Requests from GitHub...
```

You will need to set a few environment variables:

```bash
GITHUB_PRS_OAUTH_TOKEN = # (Required) A GitHub OAuth token generated from your account.
GITHUB_PRS_TEAM_ID = # (Required) The GitHub Team ID returned from GitHub's API.
GITHUB_PRS_REPO_OWNER_FILTER = # (Optional) A string that contains the names of users you'd like to filter by. (Helpful when you have a lot of forks on your repos that you don't care about.)
```


## License

MIT © David Posey
