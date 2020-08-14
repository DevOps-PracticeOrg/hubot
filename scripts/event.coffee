# Description:
# GitHub Webhookのエンドポイント
#
# Notes:
# Pull Request, Issueが対象
# /repos/{owner}/{repo}/teams
crypto = require 'crypto'
_ = require 'lodash'
test_json = require('../test.json')

ORG = if process.env.HUBOT_GITHUB_ORG then process.env.HUBOT_GITHUB_ORG else "DevOps-PracticeOrg"
QUERY_PARAM = "room"
GITHUB_LISTEN = "/github/#{ORG}"

opened = "opened"
closed = "closed"
created = "created"

module.exports = (robot) ->

    robot.router.get GITHUB_LISTEN, (request, res) ->

        #================ please set teams, repos and chat rooms =============================
        #レポジトリネームをクエリで受け取る→Roomに変換
        #転置インデックスをして、repoから検索できるようにする
        Rooms = () ->
            return inverseObj( {
                roomName: "repo1",
                katuoRoom: ["かつおスライスの仕方", "叩き"],
                maguroRoom: ["ツナ缶の作り方"],
            })
        #================ please set paires of Event and Handler  ==============================


        event_list = () ->
            return [
                setEvent('pull_request', [opened, closed])(tweetForPullRequest),
                setEvent('issues', [opened, closed])(tweetForIssues)
                setEvent('issue_comment', created)(tweetForIssueComments)
            ]


        tweetForPullRequest = (reqBody) ->
            pr = reqBody.pull_request
            return {
                opened: "#{pr.user.login}さんからPull Requestをもらいました #{pr.title} #{pr.html_url}",
                closed: "#{pr.user.login}さんのPull Requestをマージしました #{pr.title} #{pr.html_url}"
            }


        tweetForIssues = (reqBody) ->
            issue = reqBody.issue
            return {
                opened: "#{issue.user.login}さんがIssueを上げました #{issue.title} #{issue.html_url}",
                closed: "#{issue.user.login}さんのIssueがcloseされました #{issue.title} #{issue.html_url}"
            }


        tweetForIssueComments = (reqBody) ->
            issue = reqBody.issue
            comment = reqBody.comment

            message =  """
                        #{comment.user.login}さんがIssueコメントしました。
                        #{issue.user.login}さんへ：#{issue.title}
                        url: #{issue.html_url}
                        created_at: #{comment.created_at}:
                        """
            return {
                created: message

            }


        #================ Don't touch all below here ==============================

        #================ set execute_obj_list ==============================
        eventGenerate = () ->
            return (func) -> #setEvent内で呼ばれる。連想配列のvalueをラップするため

                #execute_obj_listで設定した、funcの実行部分
                emitEvent = (data, action = null) -> #実行時にdataを渡したいから、dataはここ。dataはconfig.req()を想定
                    result = func(data)
                    message = null

                    unless action?
                        message = result.default
                    else
                        message = result.action
                    
                    return message
                
                return emitEvent


        execute_obj_list = (func) ->
            return  func(event_list())


        createExecuteObjlist = (set_obj_list) ->

            event_generate = eventGenerate()

            result =  _.reduce(
                set_obj_list,
                (target, set_event) ->
                    return set_event(target, event_generate)
                ,
                {}
            )
            return result


        setEvent = (event, actionList = null) ->
            return (func) ->
                return (obj = {}, event_generate = _.indentity) ->
                    obj[event] = {}
                    obj[event]['actions'] = null

                    unless actionList?
                        obj[event]['func'] = event_generate(func)
                    else
                        checkArray = _.isArray actionList
                        actionList = if checkArray then actionList else [actionList]
                        obj[event]['func'] = event_generate(func)
                        obj[event]['actions'] = actionList
                    
                    return obj
                    # return {
                    #     eventName1: {
                    #         actions: null
                    #         func: message(IssueComments),
                    #     },
                    #     eventName2: {
                    #         actions: [open, close]
                    #         func: message(IssueComments),
                    #     }
                    # }


        #================ helper ==============================
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
            console.log("============handleEvent start!==============")
            resultObj = {
                err_msg: {},
                message: null,
            }

            event = config.event_type()
            checkEvent = _.has execute_obj, event

            unless checkEvent?
                return resultObj.err_msg['no_event'] = "#{event}:このイベントへの対応はできません。"
            else
                execute(execute_obj[event])
                # return execute(execute_obj['issues'])


        #execute_obj_listで
        execute = (event_obj) ->
            console.log("============execute start!==============")
   
            action = config.action()
            # checkEventAction = true
            checkEventAction = _.isArray event_obj.actions && _.has event_obj.actions, action
            
            # data = test_json
            data = config.req().body

            #eventGenerateの一番内部のemitEventが起動する
            emitEvent = event_obj.func
            unless checkEventAction?
                return emitEvent(data)
            else
                return emitEvent(data, action)


        pipeLine = () ->
            checkEventType
            checkAction
            createMessage
            IssueComments
            #Team名が必要かどうか
            #Org : new team,repo,member
            #Team : issue PR


        getRoom = () ->
            rooms = Room()
            repoName  = config.req().body.repository.name
            targetRoom = if _.has rooms repoName then rooms[repoName] else repoName

            return () ->
                return targetRoom


        #転置インデックス
        inverseObj = (target) ->

            inverseObj = {}
            key_list = Object.keys(target)

            for key in key_list
                values = target[key]
                value_list = if _.isArray values then values else [values]

                for value in value_list
                    inverseObj[value] = key

            return inverseObj

        # switch config.event_type()
        #     when 'issues'
        #         tweet = tweetForIssues config.req().body
        #     when 'issue_comment'
        #         tweet = tweetForIssueComments config.req().body
        #     when 'pull_request'
        #         tweet = tweetForPullRequest config.req().body


        #================ main logic ==============================
        try
            console.log "========Main stand up!========="
            config = init(request)
            Object.freeze(config)
            console.log("============show config==============")
            console.log(config)
            # checkAuth = true
            checkAuth = isCorrectSignature config
            
            console.log("============checkAuth #{checkAuth}==============")
            unless checkAuth?
                res.status(401).send 'unauthorized'
                return
            
            console.log("============execute_obj_list start!==============")
            obj = execute_obj_list(createExecuteObjlist)
            console.log(obj)
            result = handleEvent(obj)?
            console.log("============handleEvent show result==============")
            console.log(result)

            if result?
                room = getRoom()()
                console.log("============room==============")
                console.log(room)
                robot.messageRoom room, result
                res.status(201).send 'created'
            else
                res.status(200).send 'ok'

        catch e
            console.log e
            res.status(400).send "エラーです"