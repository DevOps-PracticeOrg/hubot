# Description:
# GitHub Webhookのエンドポイント
#
crypto = require 'crypto'
_ = require 'lodash'

#===================初期設定==================
ORG = if process.env.HUBOT_GITHUB_ORG then process.env.HUBOT_GITHUB_ORG else null
unless ORG
  return
GITHUB_LISTEN = "/github/#{ORG}"


log = (text) ->
  if process.env.DISPLAY_LOG == true
    console.log text
#===========================================





module.exports = (robot) ->

  robot.router.post GITHUB_LISTEN, (request, res) ->

    #================ please set paris pf repos and chat rooms =============================
    #レポジトリネームからをRoomを取得したい。現時点で、レポジトリからチームリストを取得するAPIがうまく起動しないので妥協

    Rooms = () ->
      return {
          #RepoName: "RoomName list"
          App_Laravel7: "githubnote",
          repoName1: "かつおスライスの仕方"
          repoName2: "ツナ缶の作り方",
      }

    #plz, set process.env.BOT_ADAPTER
    room_prefix = () ->
      obj = {
        SLACK: "#"
      }
      return obj[process.env.BOT_ADAPTER]

    #================ please set paires of Event and Handler  =============================
    # You can set event handlers.
    # name of event handlers needs to be same as that of event in GitHub Webhook
    # In a event handlers, You should that return function which executes `utils.getSetMessage`
    # `utils.getSetMessage` has two args.
    # The irst arg is `data` for config of a event handler.
    # The second arg is messag bady for the first arg of `data.message`.
    imple_handler_obj = () ->

      return {

        pull_request: () ->

          data = {
            actions: () ->
              return [
                "opened",
                "closed",
              ]

            message: (pull_request, action) ->

              return  """
                      "<@#{pr.user.login}>さんがPull Requestを#{action}",
                      """
          }

          return (reqBody) ->
              log("===tweetAboutPullRequest===")
              return utils.getSetMessage(data, reqBody.pull_request)

        issues: () ->

          data = {
            actions: () ->
              return [
                "opened",
                "closed",
              ]

            message: (issue, action) ->
              assignees = utils.getAssinees(issue)

              return  """
                      #{issue.url}
                      <@#{issue.user.login}>さんがIssueを#{action}。
                      #{assignees}
                      """

            defaultMessage: () ->
              return "default"
          }

          return (reqBody) ->
                log("===tweetAboutIssues===")
                return utils.getSetMessage(data, reqBody.issue)

        issue_comment: () ->

          data = {

            actions: () ->
              return [
                "opened",
                "created",
              ]

            message: (reqBody, action) ->
              issue = reqBody.issue
              comment = reqBody.comment

              return  """
                      Issueにコメントを#{action}

                      Issueタイトル：#{issue.title}
                      Issue発行者：<@#{issue.user.login}>さん
                      コメントした人：<@#{comment.user.login}>さん

                      url: #{issue.html_url}
                      """
          }

          return (reqBody) ->
              log("===tweetAboutPullRequest===")
              return utils.getSetMessage(data, reqBody)
      }

    # `event_handler_utils` can commonly be used in event handlers.
    # for example... `utils.getAssinees(list)`
    event_handler_utils = () ->
      return {
        getAssinees: (list) ->
          assignees = list.assignees
          toList = ""
          _.forEach(assignees, (assignee) ->
            toList += "<@#{assignee.login}> "
          )

          return toList
      }

    #=========================================================================
    #特定のルームに送信可能
    #特定のルームの中の特定の人へメンションできない→どうすれば？

    sendResponse = (result) ->
      if result?
        rooms = getRoom()
        log("============room==============")
        roomName = room_prefix() + rooms
        log roomName

        robot.messageRoom roomName, result
        res.status(201).send config.action()
      else
        res.status(200).send 'ok'

    sendErrorResponse = (e = null) ->
      log e
      return (func = null) ->
        unless func
          res.status(400).send "エラーです"
        else
          func()


    #================ Don't touch any sentences below==============================
    #=========================================================================
    #=========================================================================
    #=========================================================================
    #=========================================================================
    #=========================================================================
    #=========================================================================

    event_handler_default_utils = () ->
      return {
        partial: (func) ->
          return (first) ->
            return (second) ->
              return func.call(null, first, second)

        defaultMessage: (func = null) ->
          return () ->
            unless func
              return "default"
            else
              return func()

        getSetMessage: (data, body) ->
          partial_message = this.partial(data.message)(body)
          action_list = data.actions()

          list = {}
          _.forEach(action_list, (action_name) ->
            list[action_name] = () ->
              return partial_message(action_name)
          )

          unless data.defaultMessage
            list["default"] = this.defaultMessage()
          else
            list["default"] = this.defaultMessage(data.defaultMessage)

          return list
      }

    event_list = () ->

      list = []
      handler_list = imple_handler_obj()

      e_uti =  event_handler_default_utils()
      _.forEach(event_handler_utils(), (value, key) ->
        e_uti[key] = value
      )

      handler_list.__proto__.utils = e_uti
      log(handler_list)

      _.forEach(handler_list, (value, key) ->
        handler = value()
        set_event = setEvent(key)(handler)
        list.push(set_event)
      )

      return list

    config = null
    err_msg = {}
    #================ set execute_obj_list ==============================
    eventGenerate = () ->
      return (func) -> #setEvent内で呼ばれる。連想配列のvalueをラップするため

        #execute_obj_listで設定した、funcの実行部分
        return emitEvent = (data, action = null) -> #実行時にdataを渡したいから、dataはここ。dataはconfig.req()を想定
          result_message = func(data) #imple_handler_objの中身を実行

          log("==== emitEvent result =====")
          log(result)
          log("==== emitEvent action =====")
          log(action)
          message = null

          unless action?
            message = result_message['default']()
          else
            event_func = result_message[action]

            if event_func == undefined
              err_msg["no_action"] = "#{action}：対応するアクションが未定義です。"
              return

            try
              message = event_func()
            catch e
              err_msg["unexpexted"] = "予期せぬエラーが発生しました。"
              return

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


    setEvent = (event) ->
      return (func) ->
        return (obj = {}, event_generate = _.indentity) ->
          obj[event] = {}
          obj[event]['func'] = event_generate(func)

          return obj
          # return {
          #     eventName1: {
          #         func: message(IssueComments),
          #     },
          #     eventName2: {
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
      log("============handleEvent start!==============")

      event = config.event_type()
      execute_event = execute_event_list[event]
      log("============event==============")
      log( execute_event)

      unless execute_event?
          return
      else
          return execute(execute_event)#ここ！

    #execute_obj_listで
    execute = (execute_event) ->
      action = config.action()
      data = config.req().body
      log("============execute start! with action : #{action}==============")
      log(execute_event)

      #eventGenerateの内部のemitEventが起動する
      emitEvent = execute_event.func
      return emitEvent(data, action)

    getRoom = () ->
      rooms_list = Rooms()
      log "=== rooms_list ==="
      log rooms_list
      repoName  = config.req().body.repository.name
      return rooms_list[repoName]

    #================ main logic ==============================
    try

      log "========Main stand up!========="
      config = init(request)

      # checkAuth = true
      checkAuth = isCorrectSignature config

      log("============checkAuth #{checkAuth}==============")
      unless checkAuth?
          res.status(401).send 'unauthorized'
          return

      log("============execute_obj_list start!==============")
      execute_event_list = execute_obj_list(createExecuteObjlist)
      log(execute_event_list)
      result = handleEvent(execute_event_list)
      log("============handleEvent show result==============")
      log(result)

      if result == undefined
        return

      if Object.keys(err_msg).length > 0
        sendErrorResponse()()

      sendResponse(result)

    catch e
      sendErrorResponse(e)()
