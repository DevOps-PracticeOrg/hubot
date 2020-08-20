# Kitty Hubot

It is easy for you to add EventHanler on Webhook of GitHub.
This hubot sends Messaage to specified room.

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
- a value of this paires is retrieved by process.env.BOT_ADAPTER

```
room_prefix = () ->
  return {
    SLACK: "#"
  }
```

## set Event Handlers.

- set config
  - actions : require 
  - message : requrire
  - defaultMessage : no require

- set obj to return
  - event_name : requrire
  - execute : requrire

```
imple_handler_obj = () ->

  return {

    tweetAboutPullRequest: () ->

      config = {
        actions: () ->
          return [
            "opened",
            "closed",
          ]

        message: (pr) ->
          return (action) ->
            return () ->
              return  """
                      "<@#{pr.user.login}>さんがPull Requestを#{action}",
                      """
        defaultMessage: () ->
          return "default"
      }

      return {
        event_name: () ->
          return "pull_request"

        execute: (reqBody) ->
          console.log("===tweetAboutPullRequest===")
          message = config.message(reqBody.pull_request)
          return utils.getSetMessage(config, message)
        }

  }
```


## set Utils for Event Handlers.

- You can add Utils for Event Handlers.

```
handler_utils = {
  getAssinees: (list) ->
    assignees = list.assignees
    toList = ""
    _.forEach(assignees, (assignee) ->
      toList += "<@#{assignee.login}> "
    )

    return toList
}
```
- Event Hanlers has Utils as __proto__

```
# in Each of Event Handlers
utils.getAssinees(issue)
```

## Response

Response ligic is not completed yet.
- Now, Kitty can't mention a person in a room.

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

