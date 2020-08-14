# Description:
# GitHub Webhookのエンドポイント
#
# Notes:
# Pull Request, Issueが対象
# /repos/{owner}/{repo}/teams
crypto = require 'crypto'
_ = require 'lodash'

ORG = "DevOps-PracticeOrg"
QUERY_PARAM = "room"

GITHUB_LISTEN = "/github/#{ORG}/:#{QUERY_PARAM}"

config = null

module.exports = (robot) ->

    execute_obj_list = executeObjlist(
        setEvent('eventName')('funcName'),
        setEvent('eventName', "actionName")('funcName'),
        setEvent('issues')(tweetForIssues),
        setEvent('issue_comment', "actionName")(tweetForIssueComments)
        setEvent('pull_request', "opened")(tweetForPullRequest_opened)
        setEvent('pull_request', "closed")(tweetForPullRequest_closed)
    )

    tweetForPullRequest_opened = (json) ->
        action = json.action
        pr = json.pull_request
        return "#{pr.user.login}さんからPull Requestをもらいました #{pr.title} #{pr.html_url}"
        
    tweetForPullRequest_closed = (json) ->
        action = json.action
        pr = json.pull_request
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

    IssueComments = (json) ->
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


    #================ Don't touch me below ==============================

    createMessage = () ->
        return (func) ->
            return (data) -> #実行時にdataを渡したいから、dataはここ。dataはconfig.req()を想定
                return func(data)

    executeObjlist = (data) ->
        message_generate = createMessage()
        set_obj_list = _.tail(arguments)

        obj = {}
        return _.reduce(
            set_obj_list,
            (target, func) ->
                return func(target, message_generate)
            ,
            obj
        )
        return obj

    setEvent = (event, action = null) ->
            return (func) ->
                return (obj = {}, message_generate = _.indentity) ->
                    unless action?
                        obj[event] = message_generate(func)
                    else
                        obj[event][action] = message_generate(func)
                    
                    return obj
                    # return {
                    #     issues: message(IssueComments),
                    #     issue_comment: message(IssueComments),
                    #     issue_comment2: {
                    #         open: message(IssueComments),
                    #         close: message(IssueComments),
                    #     }
                    # }


    robot.router.post GITHUB_LISTEN, (request, res) ->

        config = init(request)
        config.freeze()
        checkAuth = isCorrectSignature config
        
        unless checkAuth?
            res.status(401).send 'unauthorized'
            return

   
        result = handleEvent(execute_obj_list)?
        if result?
            room = getRoom()
            robot.messageRoom room, result
            res.status(201).send 'created'
        else
            res.status(200).send 'ok'
    

        init = (request) ->
            req = _.cloneDeep request

            getRequest = () ->
                return () ->
                    return req

            getAction = () ->
                return () ->
                    return req.action

            getSignature = () ->
                signature = req.get 'X-Hub-Signature'
                return () ->
                    return signature
            
            getEventType = () ->
                event_type = req.get 'X-Github-Event'
                return () ->
                    return event_type

            obj =  {
                #valueは全てfunc型
                req: getRequest(),
                action: getAction(),
                signature: getSignature(),
                event_type: getEventType(),
            }

            return obj
        
        isCorrectSignature = (config) ->

            pairs = config.signature().split '='
            digest_method = pairs[0]
            hmac = crypto.createHmac digest_method, process.env.HUBOT_GITHUB_SECRET
            hmac.update JSON.stringify(config.req().body), 'utf-8'
            hashed_data = hmac.digest 'hex'
            generated_signature = [digest_method, hashed_data].join '='
            
            return config.signature() is generated_signature

        handleEvent = (execute_obj) ->
            resultObj = {
                err_msg: {},
                message: null,
            }

            event = config.event_type()
            checkEvent = _.has execute_obj, event

            unless checkEvent?
                resultObj.err_msg['no_event'] = "#{event}:このイベントへの対応はできません。"

            else
                setResponseMessage(execute_obj, event)

            return resultObj
        
        setResponseMessage = (execute_obj, event) ->
            
            action = config.getAction()
            checkEventAction = _.isObject event && _.has event, action

            data = config.req().body

            #createMessageの一番内部のfunctionが起動する
            if checkEventAction
                result = execute_obj.event.action(data)
            else
                result = execute_obj.event(data)

        pipeLine = () ->
            checkEventType
            checkAction
            createMessage
            IssueComments
            #Team名が必要かどうか
            #Org : new team,repo,member
            #Team : issue PR

        getRoom = () ->
            room  = config.req().params[QUERY_PARAM]
            return () ->
                return room

        # switch config.event_type()
        #     when 'issues'
        #         tweet = tweetForIssues config.req().body
        #     when 'issue_comment'
        #         tweet = tweetForIssueComments config.req().body
        #     when 'pull_request'
        #         tweet = tweetForPullRequest config.req().body