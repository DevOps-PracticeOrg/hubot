# Description:
# GitHub Webhookのエンドポイント
#
# Notes:
crypto = require 'crypto'
_ = require 'lodash'
ORG = if process.env.HUBOT_GITHUB_ORG then process.env.HUBOT_GITHUB_ORG else null
unless ORG
  return
GITHUB_LISTEN = "/github/#{ORG}"

module.exports = (robot) ->

  robot.router.post GITHUB_LISTEN, (request, res) ->

    #================ 初期設定 =============================
    err_msg = {}
    #実装済みイベント
    pull_request = "pull_request"
    issues = "issues"
    issue_comment = "issue_comment"

    #実装済みアクション
    assigned = "assigned"
    opened = "opened"
    closed = "closed"
    created = "created"

    #================ please repos and chat rooms =============================
    #レポジトリネームからをRoomを取得したい。現時点で、レポジトリからチームリストを取得するAPIがうまく起動しないので妥協

    Rooms = () ->
      return {
          App_Laravel7: ["githubnote"],
          repoName1: ["かつおスライスの仕方", "叩き"],
          repoName2: ["ツナ缶の作り方"],
      }

    event_list = () ->
      handler = imple_handler_obj()
      return [
        setEvent(pull_request, [opened, closed])(handler.tweetAboutPullRequest),
        setEvent(issues, [opened, closed, assigned])(handler.tweetAboutIssues)
        setEvent(issue_comment, created)(handler.tweetAboutIssueComments)
      ]

    #================ please set paires of Event and Handler  ==============================

    imple_handler_obj = () ->

      defaultMessage = (func = null) ->
        return () ->
          unless func
            return "default"
          else
            return func()

      getTextToAssinees = (list) ->
        assignees = list.assignees
        toList = ""
        size = Object.keys(assignees).length

        if size > 0
          --size
          for i in [0..size]
            name = "@" + assignees[i].login
            console.log("===assine_name : #{name}===")
            toList += name

            if i < size
              toList += " "

        return toList

      return {

        tweetAboutPullRequest: (reqBody) ->
          pr = reqBody.pull_request

          message = (action) ->
            return () ->
              return  """
                      "#{pr.user.login}さんがPull Requestを#{action}",
                      """

          return {
            default: defaultMessage(),
            opened: message("opened"),
            closed: message("closed")
          }


        tweetAboutIssues: (reqBody) ->
          issue = reqBody.issue
          console.log("===tweetAboutIssues===")
          assignees = getTextToAssinees(issue)
          console.log(assignees)
          message = (action) ->
            return () ->
              return  """
                      #{issue.url}
                      @#{issue.user.login}さんがIssueを#{action}。
                      #{assignees}
                      created_at: #{issue.created_at}
                      """
          return {
            default: defaultMessage(),
            assigned: message("assigned"),
            opened: message("opened"),
            closed: message("closed")
          }


        tweetAboutIssueComments: (reqBody) ->
          issue = reqBody.issue
          comment = reqBody.comment

          message = (action) ->
            return () ->
              return  """
                      #{comment.user.login}さんがIssueコメントを#{action}。
                      #{issue.user.login}さんへ：#{issue.title}
                      url: #{issue.html_url}
                      created_at: #{comment.created_at}:
                      """
          return {
              default: defaultMessage(),
              created: message("created")
            }
      }

    # dynamicExtend = (list) ->
    #   defaultMessage = (func = null) ->
    #     return () ->
    #       unless func
    #         return "default"
    #       else
    #         return func()

    #   responseMessage = (func) ->
    #     return func

    #   return () ->
    #     for i in [0..Object.keys(list).length]
    #       if list[i].defaultMessage == undefined
    #         list[i].prototype.defaultMessage = defaultMessage

    #       if list[i].responseMessage == undefined
    #         list[i].prototype.responseMessage = responseMessage

    # dynamicExtend(imple_handler_obj)

    #================ Don't touch all below here==============================
    config = null
    #================ set execute_obj_list ==============================
    eventGenerate = () ->
      return (func) -> #setEvent内で呼ばれる。連想配列のvalueをラップするため

        #execute_obj_listで設定した、funcの実行部分
        return emitEvent = (data, action = null) -> #実行時にdataを渡したいから、dataはここ。dataはconfig.req()を想定
          result = func(data)

          console.log("==== emitEvent result =====")
          console.log(result)
          console.log("==== emitEvent action =====")
          console.log(action)
          message = null

          unless action?
            message = result['default']()
          else
            event_func = result[action]

            if event_func == undefined
              err_msg["no_action"] = "#{action}：対応するアクションが未定義です。"
              return

            try
              message = event_func()
            catch e
              err_msg["unexpexted"] = "予期せぬエラーが発生しました。"
              return

          console.log("==== response message =====")
          console.log(message)
          return message

    execute_obj_list = (func) ->
      return  func(event_list())


    createExecuteObjlist = (set_obj_list) ->

      event_generate = eventGenerate()

      result =  _.reduce(
          set_obj_list,
          (target, set_event) ->
            #setEventの最奥のクロージャを起動
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


    #================ Methos ==============================
    init = (request) ->
      req = _.cloneDeep request
      getRequest = () ->
        return () ->
            return req

      getAction = () ->
        return () ->
            return req.body.action

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


    handleEvent = (execute_event_list) ->
      console.log("============handleEvent start!==============")

      event = config.event_type()
      checkEvent = execute_event_list[event]
      console.log("============event==============")
      console.log( execute_event_list[event])

      unless checkEvent?
          return
      else
          return execute(execute_event_list[event])
          # return execute(execute_obj['issues'])

    #execute_obj_listで
    execute = (execute_event) ->
      action = config.action()
      data = config.req().body
      console.log("============execute start! with action : #{action}==============")
      console.log(execute_event)

      #eventGenerateの内部のemitEventが起動する
      emitEvent = execute_event.func
      return emitEvent(data, action)

    getRoom = () ->
      rooms_list = Rooms()
      console.log "=== rooms_list ==="
      console.log rooms_list
      repoName  = config.req().body.repository.name
      return rooms_list[repoName]


    #転置インデックス：削除する
    # inverseObj = (target) ->
    #   inverseObj = {}
    #   key_list = Object.keys(target)

    #   for key in key_list
    #       values = target[key]
    #       value_list = if _.isArray values then values else [values]

    #       for value in value_list
    #           inverseObj[value] = key

    #   return inverseObj

    sendResponse = (result, pre_fix = "#") ->
      if result?
        room = getRoom()
        console.log("============room==============")
        roomName = pre_fix + room[0]
        console.log roomName
        robot.messageRoom roomName, result
        res.status(201).send config.action()
      else
        res.status(200).send 'ok'

    sendErrorResponse = (e = null) ->
      console.log e
      return (func = null) ->
        unless func
          res.status(400).send "エラーです"
        else
          func()

    #================ main logic ==============================
    try
      console.log "========Main stand up!========="
      config = init(request)
      Object.freeze(config)

      # checkAuth = true
      checkAuth = isCorrectSignature config

      console.log("============checkAuth #{checkAuth}==============")
      unless checkAuth?
          res.status(401).send 'unauthorized'
          return

      console.log("============execute_obj_list start!==============")
      execute_event_list = execute_obj_list(createExecuteObjlist)
      console.log(execute_event_list)
      result = handleEvent(execute_event_list)
      console.log("============handleEvent show result==============")
      console.log(result)

      if result == undefined
        return

      if Object.keys(err_msg).length > 0
        sendErrorResponse()()

      sendResponse(result)

    catch e
      sendErrorResponse(e)()
