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

    #================ please repos and chat rooms =============================
    #レポジトリネームからをRoomを取得したい。現時点で、レポジトリからチームリストを取得するAPIがうまく起動しないので妥協

    Rooms = () ->
      return {
          App_Laravel7: ["githubnote"],
          repoName1: ["かつおスライスの仕方", "叩き"],
          repoName2: ["ツナ缶の作り方"],
      }

    #================ please set paires of Event and Handler  =============================

    imple_handler_obj = () ->

      return {

        tweetAboutPullRequest: () ->

          config = {
            actions: () ->
              return [
                "opened",
                "opened",
              ]

            message: (pr) ->
              return (action) ->
                return () ->
                  return  """
                          "#{pr.user.login}さんがPull Requestを#{action}",
                          """
          }

          return {
            event_name: () ->
              return "pull_request"

            execute: (reqBody) ->
              console.log("===tweetAboutPullRequest===")
              message = config.message(reqBody.pull_request)
              return utils.getSetMessage(config, message)
            }

        tweetAboutIssues: () ->
          config = {
            actions: () ->
              return [
                "assigned",
                "opened",
                "closed",
              ]
            message: (issue) ->
              assignees = utils.getAssinees(issue)

              return (action) ->
                return () ->
                  return  """
                          #{issue.url}
                          @#{issue.user.login}さんがIssueを#{action}。
                          #{assignees}
                          created_at: #{issue.created_at}
                          """
          }

          return {
              event_name: () ->
                return "issues"

              execute: (reqBody) ->
                console.log("===tweetAboutIssues===")
                message = config.message(reqBody.issue)
                return utils.getSetMessage(config, message)
            }

        tweetAboutIssueComments: () ->

          config = {
            actions: () ->
              return [
                "opened",
                "created",
              ]

            message: (reqBody) ->
              issue = reqBody.issue
              comment = reqBody.comment

              return (action) ->
                return () ->
                  return  """
                          #{comment.user.login}さんがIssueコメントを#{action}。
                          #{issue.user.login}さんへ：#{issue.title}
                          url: #{issue.html_url}
                          created_at: #{comment.created_at}:
                          """
          }

          return {
            event_name: () ->
              return "issue_comment"

            execute: (reqBody) ->
              console.log("===tweetAboutPullRequest===")
              message = config.message(reqBody)
              return utils.getSetMessage(config, message)
          }
      }

    handler_utils = {

      defaultMessage: (func = null) ->
        return () ->
          unless func
            return "default"
          else
            return func()

      getSetMessage: (config, message) ->
        action_list = config.actions()
        size = Object.keys(action_list).length
        list = {}

        for i in [0..(--size)]
          action_name = action_list[i]
          list[action_name] = message(action_name)

        if list["default"] == undefined
          list["default"] = this.defaultMessage()

        return list

      getAssinees: (list) ->
        assignees = list.assignees
        toList = ""
        size = Object.keys(assignees).length

        if size > 0
          for i in [0..(--size)]
            toList += "@" + assignees[i].login + " "

        return toList
    }







    #=========================================================================
    #=========================================================================
    #=========================================================================
    #=========================================================================
    #=========================================================================
    #=========================================================================
    #================ Don't touch all below here==============================

    event_list = () ->

      list = []
      handler_list = imple_handler_obj()
      handler_list.__proto__.utils = handler_utils
      console.log("==handler_list==")
      console.log(handler_list)

      keys = Object.keys(handler_list)
      console.log(keys)

      for i in [0..(--keys.length)]
        key = keys[i]
        console.log("==key : #{key}==")
        handler = handler_list[key]()
        console.log("==handler==")
        console.log(handler)
        set_event = setEvent(handler.event_name())(handler.execute)
        list.push(set_event)

      return list

    config = null
    err_msg = {}
    #================ set execute_obj_list ==============================
    eventGenerate = () ->
      return (func) -> #setEvent内で呼ばれる。連想配列のvalueをラップするため

        #execute_obj_listで設定した、funcの実行部分
        return emitEvent = (data, action = null) -> #実行時にdataを渡したいから、dataはここ。dataはconfig.req()を想定
          result_message = func(data) #imple_handler_objの中身を実行

          console.log("==== emitEvent result =====")
          console.log(result)
          console.log("==== emitEvent action =====")
          console.log(action)
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
      console.log("============handleEvent start!==============")

      event = config.event_type()
      checkEvent = execute_event_list[event]
      console.log("============event==============")
      console.log( execute_event_list[event])

      unless checkEvent?
          return
      else
          return execute(execute_event_list[event])#ここ！

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
