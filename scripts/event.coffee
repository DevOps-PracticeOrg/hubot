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

    #実装済みイベント
    imple_event_list = () ->
      return {
        pull_request: "pull_request",
        issues: "issues",
        issue_comment: "issue_comment"
      }


    #実装済みアクション
    imple_action_list = () ->
      return {
        opened: "opened",
        closed: "closed",
        created: "created"
      }


    #================ please repos and chat rooms =============================
    #レポジトリネームからをRoomを取得したい。現時点で、レポジトリからチームリストを取得するAPIがうまく起動しないので妥協

    Rooms = () ->
      return {
          App_Laravel7: ["githubnote"],
          repoName1: ["かつおスライスの仕方", "叩き"],
          repoName2: ["ツナ缶の作り方"],
      }

    event_list = () ->
      event_list = imple_event_list()
      action_list = imple_action_list()
      return [
          setEvent(event_list.pull_request, [action_list.opened, action_list.closed])(tweetAboutPullRequest),
          setEvent(event_list.issues, [action_list.opened, action_list.closed])(tweetAboutIssues)
          setEvent(event_list.issue_comment, action_list.created)(tweetAboutIssueComments)
      ]

    #================ please set paires of Event and Handler  ==============================
    getDefaultMessage = (func = null) ->
      return () ->
        unless func
          return "default"
        else
          return func()

    tweetAboutPullRequest = (reqBody) ->
      pr = reqBody.pull_request
      return {
          default: "test",
          opened: "#{pr.user.login}さんからPull Requestをもらいました。",
          closed: "#{pr.user.login}さんのPull Requestをマージしました。"
      }


    tweetAboutIssues = (reqBody) ->
      issue = reqBody.issue
      assignees = issue.assignees

      console.log("assignees")
      for i in [0..Object.keys(assignees).length]
        console.log(assignees[i])

      message = (text) ->
        return () ->
          return """
            #{issue.url}
            @#{issue.user.login}さんがIssueを#{text}を上げました。
            assignees
            #{
              for i in [0..Object.keys(assignees).length]

                "@"+ assignees[i].login
            }
            created_at: #{comment.created_at}
            """
      return {
          default: getDefaultMessage(),
          opened: message("opened"),
          closed: message("closed")
      }


    tweetAboutIssueComments = (reqBody) ->
      issue = reqBody.issue
      comment = reqBody.comment

      message =  """
                  #{comment.user.login}さんがIssueコメントしました。
                  #{issue.user.login}さんへ：#{issue.title}
                  url: #{issue.html_url}
                  created_at: #{comment.created_at}:
                  """
      return {
          default: "test",
          created: message
      }


    #================ Don't touch all below here ==============================
    config = null
    #================ set execute_obj_list ==============================
    eventGenerate = () ->
      return (func) -> #setEvent内で呼ばれる。連想配列のvalueをラップするため

        #execute_obj_listで設定した、funcの実行部分
        emitEvent = (data, action = null) -> #実行時にdataを渡したいから、dataはここ。dataはconfig.req()を想定
          result = func(data)

          console.log("==== emitEvent result =====")
          console.log(result)
          console.log("==== emitEvent action =====")
          console.log(action)
          message = null

          unless action?
              message = result['default']()
          else
              message = result[action]()

          console.log("==== response message =====")
          console.log(message)
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


    handleEvent = (execute_obj) ->
      console.log("============handleEvent start!==============")
      resultObj = {
          err_msg: {},
          message: null,
      }

      event = config.event_type()
      checkEvent = execute_obj[event]
      console.log("============event==============")
      console.log( execute_obj[event])

      unless checkEvent?
          return resultObj.err_msg['no_event'] = "#{event}:このイベントへの対応はできません。"
      else
          return execute(execute_obj[event])
          # return execute(execute_obj['issues'])

    #execute_obj_listで
    execute = (event_obj) ->
      console.log("============execute start! with action : #{action}==============")
      console.log(event_obj)

      action = config.action()
      data = config.req().body

      #eventGenerateの一番内部のemitEventが起動する
      emitEvent = event_obj.func
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
      res.status(400).send "エラーです"

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
      obj = execute_obj_list(createExecuteObjlist)
      console.log(obj)
      result = handleEvent(obj)
      console.log("============handleEvent show result==============")
      console.log(result)

      sendResponse(result)

    catch e
      sendErrorResponse(e)
