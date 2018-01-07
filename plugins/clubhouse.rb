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

user_uuid = nil
Clubhouse::User.all.each do |user|
  if user.username == ENV['CLUBHOUSE_USERNAME']
    puts 'User id for ' + ENV['CLUBHOUSE_USERNAME'] + ' is ' + user.id
    user_uuid = user.id
  end
end

if user_uuid == nil
  throw 'Couldn\'t find user. Check that CLUBHOUSE_USERNAME is correct'
end

workflow_state_ids_to_show = []
Clubhouse::Workflow.all.each do |workflow|
  workflow.states.each do |workflow_state|
    if ['unstarted', 'started'].include? workflow_state.type
      workflow_state_ids_to_show.push(workflow_state.id)
    end
  end
end

if workflow_state_ids_to_show.empty?
  throw 'Couldn\'t find some valid workflow step to shows.'
end

story_identifier = []

stories = Clubhouse::Story.search(owner_id: user_uuid)
stories.each do |story|
  project_name = Clubhouse::Project.find(story.project_id).name
  epic_name = Clubhouse::Epic.find(story.epic_id).name rescue "No Epic"
  story_id = "[%s-%s #%d]" % [project_name, epic_name, story.id]
  story_url = "https://app.clubhouse.io//story/" + story.id.to_s
  story_should_be_shown = workflow_state_ids_to_show.include? story.workflow_state_id

  story_identifier.push(story_id)

  task = project.tasks[its.name.contains(story_id)].first.get rescue nil
  if task
    if story_should_be_shown && task.completed.get
      puts 'Uncompleting in OmniFocus: ' + story_id
      task.completed.set false
    elsif !story_should_be_shown && !task.completed.get
      puts 'Completing in OmniFocus: ' + story_id
      task.completed.set true
    else
      puts 'Updating in OmniFocus: ' + story_id
      update_if_changed task, :note, story_url
      update_if_changed task, :name, "%s %s" % [story_id, story.name]
    end
  elsif story_should_be_shown
    puts 'Adding: ' + story_id
    project.make :new => :task, :with_properties => {
      :name => "%s %s" % [story_id, story.name],
      :note => story_url,
    }
  end
end

project.tasks().get.each do |task|
  if !task.completed.get
    task_name = task.name().get
    matches = /(?<identifier>\[([a-zA-Z ]*-([a-zA-Z ]|-)*) #([1-9][0-9]*)\])/.match(task_name)
    if matches && matches.size == 2
      story_id = matches["identifier"]

      if !story_identifier.include? story_id
        puts "Removing task #{story_id} in OmniFocus because assignment was removed"
        $omnifocus.delete task
      end
    end
  end
end
