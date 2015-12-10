#!/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'pry'
require 'faraday'
require 'faraday_middleware'
require 'readline'

require_relative 'camunda_api'

camunda = Camunda.new

groups = [{id: 'screeners', name: 'screeners', type: 'WORKFLOW'},
          {id: 'applicants', name: 'applicants', type: 'WORKFLOW'}]
group_ids = groups.map { |group| group[:id] }

camunda.groups.select { |group| group_ids.include?(group.id) }.each(&:delete)
admins_group = camunda.groups.detect { |group| group.id == 'camunda-admin' }
screeners_group, applicants_group = groups.map { |group| Group.new(group).create }

users = [{id: 'applicant', first_name: 'Designer', last_name: 'Applicant', password: 'password'},
         {id: 'screener1', first_name: 'Screener', last_name: 'One', password: 'password'},
         {id: 'screener2', first_name: 'Screener', last_name: 'Two', password: 'password'},
         {id: 'screener3', first_name: 'Screener', last_name: 'Three', password: 'password'}]

user_ids = users.map { |user| user[:id] }
camunda.users.select { |user| user_ids.include?(user.id) }.each(&:delete)

applicant, *screeners = users.map { |user| User.new(user).create }

applicant.add_to_group(applicants_group)
screeners.each { |screener| screener.add_to_group(screeners_group) }

if admins_group
  applicant.add_to_group(admins_group)
  screeners.each { |screener| screener.add_to_group(admins_group) }
end

camunda.filters.each(&:delete)
filters = [{resource_type: 'Task', name: 'My Tasks', owner: 'demo', query: {'assigneeExpression': '${currentUser()}'}},
           {resource_type: 'Task', name: 'My Group Tasks', owner: 'demo', query: {'candidateGroupsExpression': '${currentUserGroups()}'}}]
filters.map { |filter| Filter.new(filter).create }

camunda.process_instances.select { |instance| instance.definition_id.start_with?('PortfolioReview:') }.each(&:delete)
camunda.deployments.select { |deployment| deployment.name == 'process' }.each(&:delete)

Deployment.new(name: 'process').create(file_name: 'diagram.bpmn')

camunda.process_definitions.select { |definition| definition.id.start_with?('PortfolioReview:') }.each(&:start)

stty_save = `stty -g`.chomp
trap('INT') do
  system 'stty', stty_save
  exit
end

SUBCOMMANDS = {
  global: [:groups, :users, :process_definitions, :process_instances, :tasks, :deployments, :filters]
}
COMMON_SUBCOMMANDS = [:back]

context = :global
context_obj = camunda

loop do
  commands = (SUBCOMMANDS[context] || []) + COMMON_SUBCOMMANDS
  Readline.completion_proc = proc { |cmd| commands.grep(/^#{Regexp.escape(cmd)}/) }
  Readline.completion_append_character = ''
  puts "#{commands.join('; ')}"
  cmd = Readline.readline("#{context}> ", true)
  break unless cmd

  cmd = cmd.to_sym
  next unless commands.include?(cmd)

  case cmd
  when :back
    context = :global
    context_obj = camunda
  else
    context = cmd
    context_obj = context_obj.send(cmd)
    # List entities
    context_obj.each { |entity| puts entity }
  end
end
