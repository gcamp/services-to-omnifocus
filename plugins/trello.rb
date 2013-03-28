#
# Create OmniFocus tasks for cards assigned to you in Trello. Works across
# boards and also supports up to one checklist of sub-items (tasks per card). 
# Each board in Trello is reflected as a project in OmniFocus, which has to
# exist before you are able to sync it to OmniFocus (and can be setup any way
# you like with default contexts, sequential or parallel, etc.)
# When cards change in Trello, those changes are reflected in OmniFocus. Changes
# to tasks in OmniFocus are *not* synced back to Trello at this point.
#
# Authentication data is taken from these environment variables:
#
#   TRELLO_DEVELOPER_PUBLIC_KEY: Contains a developer API key generated by Trello
#                 (https://trello.com/1/appKey/generate)
#   TRELLO_MEMBER_TOKEN: Contains a member token generated based on the above
#                        developer API key
#                 (https://trello.com/1/authorize?key=YOURDEVKEY&expiration=never&name=Services+to+OmniFocus&response_type=token&scope=read,write)
#

require "trello"

Trello.configure do |config|
  config.developer_public_key = ENV['TRELLO_DEVELOPER_PUBLIC_KEY']
  config.member_token = ENV['TRELLO_MEMBER_TOKEN']
end

Trello::Member.find('my').cards.each do |card|
  next if card.board.closed?
  project_name = card.board.name
  project = $omnifocus.flattened_projects[project_name].get
  task_id = "[#%d]" % card.short_id
  task = project.tasks[its.name.contains(task_id)].first.get rescue nil

  if task
    next if task.completed.get && card.list.name.downcase == 'done'
    if task.completed.get
      puts 'Completing in Trello: ' + card.name
      done_list = card.board.lists.detect { |l| l.name.downcase == 'done' }
      card.move_to_list(done_list)
    elsif card.list.name.downcase == 'done'
      puts 'Completing in OmniFocus: ' + card.name
      task.completed.set true
    else
      update_if_changed task, :note, card.url
      update_if_changed task, :name, "%s %s" % [card.name, task_id]
    end
  elsif card.list.name.downcase != 'done'
    puts 'Adding: ' + card.name
    task = project.make :new => :task, :with_properties => {
      :name => "%s %s" % [card.name, task_id],
      :note => card.url,
    }
  end

  if checklist = card.checklists.first
    completed_items = card.check_item_states.
      find_all { |is| is.state == 'complete' }.collect(&:item_id)
    checklist.items.each do |item|
      subtask = task.tasks[its.note.contains(item.id)].first.get rescue nil
      if subtask
        update_if_changed subtask, :name, item.name
      else
        puts 'Adding sub-task: %s' % item.name
        subtask = task.make :new => :task, :with_properties => {
          :name => item.name,
          :note => item.id,
        }
      end
      next if subtask.completed.get && completed_items.include?(item.id)
      if subtask.completed.get
        puts 'Completing sub-task in Trello: ' + item.name
        # Not implemented in ruby-trello, unfortunately
        Trello.client.put "/cards/#{card.id}/checklist/#{checklist.id}" +
          "/checkItem/#{item.id}/state", :value => 'complete'

      elsif completed_items.include?(item.id)
        puts 'Completing sub-task in OmniFocus: ' + item.name
        subtask.completed.set true
      end
    end
  end
end
