#
# Create OmniFocus tasks for issues assigned to you in GitHub. Works across repos.
# When issues change in GitHub, those changes are reflected in OmniFocus. Changes
# to tasks in OmniFocus are *not* synced back to GitHub at this point.
#
# Authentication data is taken from these environment variables:
#
#   GITHUB_TOKEN: Contains an Oauth token created using the Authorizations API
#                 (http://developer.github.com/v3/oauth/#create-a-new-authorization)
#

require "github_api"

github = Github.new :oauth_token => ENV['GITHUB_TOKEN']
project = $omnifocus.flattened_projects["GitHub"].get

def get_repo_name(html_url)
  URI(html_url).path.split(/\//)[1..2].join('/')
end

issues = [ github.issues.list, github.issues.list(:state => 'closed') ].flatten;
task_identifiers = []

issues.each do |i|
  repo = get_repo_name(i.html_url)
  task_id = "[%s #%d]" % [repo, i.number]
  task_identifiers.push(task_id)
  task = project.tasks[its.name.contains(task_id)].first.get rescue nil

  if task
    if i.state.to_sym != :closed && task.completed.get
      puts 'Uncompleting in OmniFocus: ' + task_id
      task.completed.set false
    elsif i.state.to_sym == :closed &&  !task.completed.get
      puts 'Completing in OmniFocus: ' + task_id
      task.completed.set true
    else
      update_if_changed task, :note, i.html_url
      update_if_changed task, :name, "%s %s" % [task_id, i.title]
    end
  elsif i.state.to_sym != :closed
    puts 'Adding: ' + task_id
    project.make :new => :task, :with_properties => {
      :name => "%s %s" % [task_id, i.title],
      :note => i.html_url,
    }
  end
end

project.tasks().get.each do |task|
  if !task.completed.get
    task_name = task.name().get
    matches = /(?<identifier>\[([a-zA-Z]*\/([a-zA-Z]|-)*) #([1-9][0-9]*)\])/.match(task_name)
    if matches && matches.size == 2
      task_id = matches["identifier"]

      if !task_identifiers.include? task_id
        puts "Removing task #{task_id} in OmniFocus because assignment was removed"
        $omnifocus.delete task
      end
    end
  end
end
