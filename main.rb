require 'bundler'
Bundler.require :default, :development

get '/' do
    "Hi there! Bob!"
end
configure do
    if not Dir.exists? "/tmp/checkout"
        Dir.mkdir "/tmp/checkout"
    end
end
helpers do
    def get_user_commits user
        response = Curl::Easy.perform("https://api.github.com/users/#{user}/events") do |curl|
            curl.headers["User-Agent"] = "d4l3k"
        end
        events = MultiJson.load(response.body)
        commits = []
        events.each do |event|
            if event["type"]=="PushEvent"
                commits += event["payload"]["commits"]
            end
        end
        commits
    end
    def get_user_commits_multi user
        responses = {}
        requests = []
        (1..10).each do |i|
            requests.push "https://api.github.com/users/#{user}/events?page=#{i}"
        end
        m = Curl::Multi.new
        m.pipeline = true
        # add a few easy handles
        requests.each do |url|
          responses[url] = ""
          c = Curl::Easy.new(url) do|curl|
            curl.headers["User-Agent"] = "d4l3k"
            curl.follow_location = true
            curl.on_body{|data| responses[url] << data; data.size }
          end
          m.add(c)
        end

        m.perform do
          puts "idling... can do some work here, including add new requests"
        end
        commits = []
        responses.each do|url, data|
            events = MultiJson.load(data)
            events.each do |event|
                if event.is_a? Array
                    binding.pry
                end
                if event["type"]=="PushEvent"
                    commits += event["payload"]["commits"]
                end
            end
        end
        commits
    end
    def get_commit_info commits
        responses = {}
        m = Curl::Multi.new
        m.pipeline = true
        # add a few easy handles
        commits.each do |commit|
            url = commit["url"]
            responses[url] = ""
            c = Curl::Easy.new(url) do|curl|
                curl.headers["User-Agent"] = "d4l3k"
                curl.follow_location = true
                curl.on_body{|data| responses[url] << data; data.size }
            end
            m.add(c)
        end

        m.perform do
          puts "idling... can do some work here, including add new requests"
        end
    end
end
=begin
get '/:user/' do
    commits = get_user_commits_multi params[:user]
    info = get_commit_info commits
    binding.pry
end
=end
get '/:user/:repo/' do
    user = params[:user]
    repo = params[:repo]
    remote = "git@github.com:#{user}/#{repo}.git"
    puts remote
    system("git", "clone", "-n", remote, "/tmp/checkout/#{user}-#{repo}")
    text = `git_time_extractor /tmp/checkout/#{user}-#{repo}`
    data = CSV.parse(text)
    time = 0
    commits = 0
    data.each do |line|
        commits += 1
        time += line[1].to_i
    end
    "Number of coding sessions: #{commits}, Hours: #{time/60.0}"
end
