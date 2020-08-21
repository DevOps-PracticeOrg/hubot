# Kitty Hubot

It is easy for you to add EventHanler on Webhook of GitHub.
This hubot sends a messaage to a specified room.

## set pairs of repogitory names and room names.

```
Rooms = () ->
  return {
      #RepoName: "RoomName"
      App_Laravel7: "githubnote",
      repoName1: "かつおスライスの仕方"
      repoName2: "ツナ缶の作り方",
  }
```

## set pairs of adapter and prefix.
- a value of this paires is retrieved by `process.env.BOT_ADAPTER`
- You need set `process.env.BOT_ADAPTER`
```
room_prefix = () ->
  obj = {
    SLACK: "#"
  }
  return obj[process.env.BOT_ADAPTER]
```

## set Event Handlers.

You can set event handlers.  
Name of event handlers needs to be same as that of event in [GitHub Webhook](https://developer.github.com/webhooks/event-payloads/).  
In a event handlers, You should return the function which executes `utils.getSetMessage`  
`utils.getSetMessage` has two args.  
The irst arg is `data` for config of a event handler.  
The second arg is messag bady for the first arg of `data.message`.  

- set config
  - actions : require 
  - message : requrire
  - defaultMessage : no require


```
imple_handler_obj = () ->

  return {

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

  }
```


## set Utils for Event Handlers.

- `event_handler_utils` can commonly be used in event handlers.
- for example... `utils.getAssinees(list)`

```
event_handler_utils = {
  return {
    getAssinees: (list) ->
      assignees = list.assignees
      toList = ""
      _.forEach(assignees, (assignee) ->
        toList += "<@#{assignee.login}> "
      )

      return toList
}
```

## Response

Response logic is not completed yet.  
`Now, Kitty can't specify(mention to) a person in a room.`

```
sendResponse = (result) ->
  if result?
    rooms = getRoom()
    console.log("============room==============")
    roomName = room_prefix()[process.env.BOT_ADAPTER] + rooms
    console.log roomName

    robot.messageRoom roomName, result
    res.status(201).send config.action()
  else
    res.status(200).send 'ok'
```

