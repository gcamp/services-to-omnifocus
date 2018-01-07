#
# Create OmniFocus tasks for issues assigned to you in Clubhouse. Works across repos.
# When issues change in Clubhouse, those changes are reflected in OmniFocus. Changes
# to tasks in OmniFocus are *not* synced back to Clubhouse at this point.
#
# Authentication data is taken from these environment variables:
#
#   CLUBHOUSE_TOKEN: Contains an Oauth token created using the Authorizations API
#                    (https://app.clubhouse.io/settings/account/api-tokens)
#   CLUBHOUSE_USERNAME : Contains the username of your user in clubhouse.
#   CLUBHOUSE_WORKFLOW_NAMES_TO_SHOW : Comma seperated list of workflow state name
#                                      that should be shown in Omnifocus
#

require "clubhouse"

Clubhouse.default_client = Clubhouse::Client.new(ENV['CLUBHOUSE_TOKEN'])
project = $omnifocus.flattened_projects["Clubhouse"].get

myUserUUID = nil
Clubhouse::User.all.each do |user|
  if user.username == ENV['CLUBHOUSE_USERNAME']
    puts 'User id for ' + ENV['CLUBHOUSE_USERNAME'] + ' is ' + user.id
    myUserUUID = user.id
  end
end

if myUserUUID == nil
  throw 'Couldn\'t find user. Check that CLUBHOUSE_USERNAME is correct'
end

workflowStateIdsToShow = []
Clubhouse::Workflow.all.each do |workflow|
  workflow.states.each do |workflowState|
    if ['unstarted', 'started'].include? workflowState.type
      workflowStateIdsToShow.push(workflowState.id)
    end
  end
end

if workflowStateIdsToShow.empty?
  throw 'Couldn\'t find some valid workflow step to shows.'
end

stories = Clubhouse::Story.search(owner_id: myUserUUID)
stories.each do |story|
  projectName = Clubhouse::Project.find(story.project_id).name
  epicName = Clubhouse::Epic.find(story.epic_id).name rescue "No Epic"
  storyId = "[%s-%s #%d]" % [projectName, epicName, story.id]
  storyUrl = "https://app.clubhouse.io//story/" + story.id.to_s
  storyShouldBeShown = workflowStateIdsToShow.include? story.workflow_state_id

  task = project.tasks[its.name.contains(story_id)].first.get rescue nil
  if task
    if storyShouldBeShown && !task.completed.get
      puts 'Completing in OmniFocus: ' + storyId
      task.completed.set true
    else
      update_if_changed task, :note, storyUrl
      update_if_changed task, :name, "%s %s" % [storyId, story.name]
    end
  elsif storyShouldBeShown
    puts 'Adding: ' + storyId
    project.make :new => :task, :with_properties => {
      :name => "%s %s" % [storyId, story.name],
      :note => storyUrl,
    }
  end
end

# def get_repo_name(html_url)
#   URI(html_url).path.split(/\//)[1..2].join('/')
# end
#
# issues = [ github.issues.list, github.issues.list(:state => 'closed') ].flatten;
# task_identifiers = []
#
# issues.each do |i|
#   repo = get_repo_name(i.html_url)
#   task_id = "[%s #%d]" % [repo, i.number]
#   task_identifiers.push(task_id)
#   task = project.tasks[its.name.contains(task_id)].first.get rescue nil
#
#   if task
#     if i.state.to_sym == :closed &&  !task.completed.get
#       puts 'Completing in OmniFocus: ' + task_id
#       task.completed.set true
#     else
#       update_if_changed task, :note, i.html_url
#       update_if_changed task, :name, "%s %s" % [task_id, i.title]
#     end
#   elsif i.state.to_sym != :closed
#     puts 'Adding: ' + task_id
#     project.make :new => :task, :with_properties => {
#       :name => "%s %s" % [task_id, i.title],
#       :note => i.html_url,
#     }
#   end
# end
#
# project.tasks().get.each do |task|
#   if !task.completed.get
#     task_name = task.name().get
#     matches = /(?<identifier>\[([a-zA-Z]*\/([a-zA-Z]|-)*) #([1-9][0-9]*)\])/.match(task_name)
#     if matches && matches.size == 2
#       task_id = matches["identifier"]
#
#       if !task_identifiers.include? task_id
#         puts "Removing task #{task_id} in OmniFocus because assignment was removed"
#         $omnifocus.delete task
#       end
#     end
#   end
# end
