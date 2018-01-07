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

storyIdentifier = []

stories = Clubhouse::Story.search(owner_id: myUserUUID)
stories.each do |story|
  projectName = Clubhouse::Project.find(story.project_id).name
  epicName = Clubhouse::Epic.find(story.epic_id).name rescue "No Epic"
  storyId = "[%s-%s #%d]" % [projectName, epicName, story.id]
  storyUrl = "https://app.clubhouse.io//story/" + story.id.to_s
  storyShouldBeShown = workflowStateIdsToShow.include? story.workflow_state_id

  storyIdentifier.push(storyId)

  task = project.tasks[its.name.contains(storyId)].first.get rescue nil
  if task
    if storyShouldBeShown && task.completed.get
      puts 'Uncompleting in OmniFocus: ' + storyId
      task.completed.set false
    elsif !storyShouldBeShown && !task.completed.get
      puts 'Completing in OmniFocus: ' + storyId
      task.completed.set true
    else
      puts 'Updating in OmniFocus: ' + storyId
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

project.tasks().get.each do |task|
  if !task.completed.get
    task_name = task.name().get
    matches = /(?<identifier>\[([a-zA-Z ]*-([a-zA-Z ]|-)*) #([1-9][0-9]*)\])/.match(task_name)
    if matches && matches.size == 2
      story_id = matches["identifier"]

      if !storyIdentifier.include? story_id
        puts "Removing task #{story_id} in OmniFocus because assignment was removed"
        $omnifocus.delete task
      end
    end
  end
end
