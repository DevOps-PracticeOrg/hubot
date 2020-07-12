module.exports = (robot) ->

	github = require("githubot")(robot)

	unless (url_api_base = process.env.HUBOT_GITHUB_API)?
		url_api_base = "https://api.github.com"
		
	_getDate = ->
		theDate = new Date
		yyyy = theDate.getFullYear()
		mm = theDate.getMonth()+1 #January is 0!
		if mm < 10
			mm = "0" + mm
		dd = theDate.getDate()
		if dd < 10
			dd = "0" + dd
		yyyy + "." + mm + "." + dd
					
	robot.respond /deploy ([-_\.0-9a-zA-Z]+)(\/([-_\.a-zA-z0-9\/]+))? into (deployment\/([-_\.a-zA-z0-9\/]+))$/i, (msg)->
		repo = msg.match[1]
		head = msg.match[3] || "master"
		base = msg.match[4]
		environment = msg.match[5]
		
		url = "#{url_api_base}/repos/qwintet-dev/#{repo}/pulls" #GitHubAPIのURL
		
		account_name = msg.envelope.user.name || "anonymous" #このスクリプトを呼び出した人のSlackアカウント名
		channel_name = msg.envelope.room || "anonymous" #このスクリプトを呼び出したSlackのChannel
		
		title = "#{_getDate()} #{environment} deployment by #{account_name}"
		circleCIUrl = "https://circleci.com/gh/qwintet-dev/#{repo}/tree/#{encodeURIComponent(base)}" #CircleCIのURL
		
		body = """
			・Created By #{account_name} on #{channel_name} Channel
			・Circle CI build status can be shown: #{circleCIUrl}
		"""
		
		data = {
			"title": title
			"body": body
			"head": head
			"base": base
		}
		
		github.post url, data, (pull) ->
			msg.send "プルリク作りました " + pull.html_url