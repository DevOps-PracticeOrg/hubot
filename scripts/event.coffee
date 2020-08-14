# Description:
# GitHub Webhookのエンドポイント
#
# Notes:
# Pull Request, Issueが対象
# /repos/{owner}/{repo}/teams
crypto = require 'crypto'

module.exports = (robot) ->

    robot.router.post "/github/webhook", (req, res) ->
        event_type = req.get 'X-Github-Event'
        signature = req.get 'X-Hub-Signature'

        signOk = isCorrectSignature signature, req.body
        
        getTeamListbyRepo()

        unless signOk?
            res.status(401).send 'unauthorized'
            return
               
        tweet = null
        switch event_type
            when 'issues'
                tweet = tweetForIssues req.body
            when 'issue_comment'
                tweet = tweetForIssueComments req.body
            when 'pull_request'
                tweet = tweetForPullRequest req.body

        
        if tweet?
            robot.messageRoom '#githubnote', tweet
            # robot.send {}, tweet
            res.status(201).send 'created'
        else
            res.status(200).send 'ok'
            
    isCorrectSignature = (signature, body) ->

        pairs = signature.split '='
        digest_method = pairs[0]
        hmac = crypto.createHmac digest_method, process.env.HUBOT_GITHUB_SECRET
        hmac.update JSON.stringify(body), 'utf-8'
        hashed_data = hmac.digest 'hex'
        generated_signature = [digest_method, hashed_data].join '='
        
        return signature is generated_signature

    tweetForPullRequest = (json) ->
        action = json.action
        pr = json.pull_request
        switch action
            when 'opened'
                return "#{pr.user.login}さんからPull Requestをもらいました #{pr.title} #{pr.html_url}"
            when 'closed'
                if pr.merged
                  return "#{pr.user.login}さんのPull Requestをマージしました #{pr.title} #{pr.html_url}"
        
    tweetForIssues = (json) ->
        action = json.action
        issue = json.issue

        switch action
            when 'opened'
                return "#{issue.user.login}さんがIssueを上げました #{issue.title} #{issue.html_url}"
            when 'closed'
                return "#{issue.user.login}さんのIssueがcloseされました #{issue.title} #{issue.html_url}"

     tweetForIssueComments = (json) ->
        action = json.action
        message = null

        switch action
            when 'created'
                issue = json.issue
                comment = json.comment
                message =  """
                            #{comment.user.login}さんがIssueコメントしました。
                            #{issue.user.login}さんへ：#{issue.title}
                            url: #{issue.html_url}
                            created_at: #{comment.created_at}:
                            """
        
        return message

    getTeamListbyRepo = () ->
        console.log "...getTeamListbyRepo"

        robot.http("https://api.github.com/repos/DevOps-PracticeOrg/hubot/teams")
            .get() (err, res, body) ->
                try
                    console.log res
                    console.log "==========================="
                    console.log body
                    console.log "==========================="
                catch e