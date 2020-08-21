module.exports = (robot) ->
  robot.hear(/愛してる/i, (res) ->
    res.reply("私も愛してるわ")
  )
  robot.hear(/付き合って/i, (res) ->
    res.reply("ごめんさない。私は皆んなのアイドルなの・・・")
  )
