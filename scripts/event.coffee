# Description:
# GitHub Webhookのエンドポイント
#
# Notes:
# Pull Request, Issueが対象
# /repos/{owner}/{repo}/teams
crypto = require 'crypto'
_ = require 'lodash'

ORG = if process.env.ORGANIZATION_NAME then process.env.ORGANIZATION_NAME else "test"
QUERY_PARAM = "room"
GITHUB_LISTEN = "/github/#{ORG}/:#{QUERY_PARAM}"

opened = "opened"
closed = "closed"
created = "created"

module.exports = (robot) ->
    robot.router.post GITHUB_LISTEN, (request, res) ->

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
        execute_obj_list = createExecuteObjList(
            setEvent('eventName')('funcName'),
            setEvent('eventName', "actionName")('funcName'),
            setEvent('pull_request', [opened, closed])(tweetForPullRequest),
            setEvent('issues', [opened, closed])(tweetForIssues)
            setEvent(issue_comment, created)(tweetForIssueComments)
        )

        tweetForPullRequest = (reqBody) ->
            action = reqBody.action
            pr = reqBody.pull_request
            return {
                opened: "#{pr.user.login}さんからPull Requestをもらいました #{pr.title} #{pr.html_url}",
                closed: "#{pr.user.login}さんのPull Requestをマージしました #{pr.title} #{pr.html_url}"
            }
            
        tweetForIssues = (reqBody) ->
            action = reqBody.action
            issue = reqBody.issue
            return {
                opened: "#{issue.user.login}さんがIssueを上げました #{issue.title} #{issue.html_url}",
                closed: "#{issue.user.login}さんのIssueがcloseされました #{issue.title} #{issue.html_url}"
            }


        tweetForIssueComments = (reqBody) ->
            action = reqBody.action
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

        createExecuteObjlist = (set_obj_list) ->
            event_generate = eventGenerate()

            return _.reduce(
                set_obj_list,
                (target, set_event) ->
                    return set_event(target, event_generate)
                ,
                obj
            )
            return obj

        setEvent = (event, actionList = null) ->
            return (func) ->
                return (obj = {}, event_generate = _.indentity) ->
                    obj[event]['actions'] = null

                    unless actionList?
                        obj[event]['func'] = event_generate(func)
                    else
                        checkArray = _.isArray actionList
                        actionList = if checkArray then actionList else _.toArray actionList
                        obj[event]['func'] = event_generate(func)
                        obj[event]['actions'] = actionList
                    
                    console.log(obj)
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



        #================ main logic ==============================

        main()

        main = () ->
            config = init(request)
            config.freeze()
            
            checkAuth = isCorrectSignature config
            
            unless checkAuth?
                res.status(401).send 'unauthorized'
                return

    
            result = handleEvent(execute_obj_list)?
            if result?
                room = getRoom()()
                robot.messageRoom room, result
                res.status(201).send 'created'
            else
                res.status(200).send 'ok'
   
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
            resultObj = {
                err_msg: {},
                message: null,
            }

            event = config.event_type()
            checkEvent = _.has execute_obj, event

            unless checkEvent?
                resultObj.err_msg['no_event'] = "#{event}:このイベントへの対応はできません。"

            else
                execute(execute_obj[event])

            return resultObj
        
        #execute_obj_listで
        execute = (event_obj) ->
            
            action = config.getAction()
            checkEventAction = _.isArray event_obj.actions && _.has event_obj.actions, action

            data = config.req().body

            #eventGenerateの一番内部のemitEventが起動する
            event_generate = execute_obj.event.func
            unless checkEventAction?
                result = emitEvent(data)
            else
                result = emitEvent(data, action)

        pipeLine = () ->
            checkEventType
            checkAction
            createMessage
            IssueComments
            #Team名が必要かどうか
            #Org : new team,repo,member
            #Team : issue PR

        getRoom = () ->
            repoName  = config.req().params[QUERY_PARAM]
            rooms = Room()

            targetRoom = if _.has rooms repoName then rooms[repoName] else repoName

            return () ->
                return targetRoom

        #転置インデックス
        inverseObj = (target) ->

            inverseObj = {}
            key_list = Object.keys(target)
        
            for key in key_list
                values = target[key]
                value_list = if _.isArray values then values else _.toArray values

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