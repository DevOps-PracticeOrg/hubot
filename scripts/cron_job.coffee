module.exports = (robot) ->

  # 定期処理をするオブジェクトを宣言
  JapaneseHolidays = require('japanese-holidays')
  Github = require("githubot")
  CronJob = require('cron').CronJob

  SLACK_USER_NAME = "domonr"

  # pr って言うとpr一覧を出してくれます
  robot.respond /pr/i, (msg) ->
    _notificationPullRequestList(msg)

  # Crontabの設定方法と基本一緒 *(sec) *(min) *(hour) *(day) *(month) *(day of the week)
  # 以下の設定だと平日の15:00に実行されます
  job = new CronJob '0 0 15 * * 1-5', () ->
    today = new Date();
    holiday = JapaneseHolidays.isHoliday(today);
    if holiday 
      console.log("今日は " + holiday + " です")
    else
      _notificationPullRequestList()
  job.start()

  # 特定のチャンネルへ送信するメソッド(定期実行時に呼ばれる)　
  _notificationPullRequestList = (msg) ->
    Github.get 'https://api.github.com/user', (user) ->
      Github.get 'https://api.github.com/user/repos', (repos) ->
        for repo in repos
          do ->
            _repo = repo
            Github.get "https://api.github.com/repos/#{_repo.full_name}/pulls?state=open", (prs) ->
              for pr in prs
                do ->
                  _pr = pr
                  Github.get "https://api.github.com/repos/#{_repo.full_name}/pulls/#{_pr.number}/requested_reviewers", (reviewers) ->
                    for reviewer in reviewers
                      do ->
                        _reviewer = reviewer
                        if _reviewer.login == user.login
                          robot.messageRoom "@#{SLACK_USER_NAME}", "Repo:#{_repo.full_name}\nTitle:#{_pr.title}\nURL:#{_pr.html_url}"
    return