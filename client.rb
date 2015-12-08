#!/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'pry'
require 'faraday'
require 'faraday_middleware'
require 'readline'

class Camunda
  BASE_URL = 'http://localhost:8080/bpm-sample/'.freeze
  DEBUG = false

  def initialize
    @conn = Faraday.new(url: BASE_URL) do |faraday|
      faraday.request  :multipart
      faraday.request  :json

      faraday.adapter  Faraday.default_adapter

      faraday.response :json, content_type:  /\bjson$/
      faraday.response :raise_error
      faraday.response :logger if DEBUG
    end
  end

  def groups
    @conn.get('group').body
  end

  def delete_group(group)
    @conn.delete("group/#{group['id']}")
  end

  def create_group(id:, name:, type:)
    group = {id: id, name: name, type: type}
    @conn.post('group/create', group)
    group
  end

  def users
    @conn.get('user').body
  end

  def create_user(id:, first_name:, last_name:, email:, password:)
    profile = {id: id, firstName: first_name, lastName: last_name, email: email}
    @conn.post('user/create',
               profile: profile,
               credentials: {password: password})
    profile
  end

  def delete_user(user)
    @conn.delete("user/#{user['id']}")
  end

  def create_group_member(group, user)
    @conn.put("group/#{group[:id]}/members/#{user[:id]}")
  end

  def deployments
    @conn.get('deployment').body
  end

  def create_deployment(name:, file_name:)
    file = Faraday::UploadIO.new(file_name, 'text/xml')
    @conn.post('deployment/create', 'deployment-name': name, file: file).body
  end

  def delete_deployment(deployment)
    @conn.delete("deployment/#{deployment['id']}")
  end

  def executions
    @conn.get('execution').body
  end

  def process_definitions
    @conn.get('process-definition').body
  end

  def process_instances
    @conn.get('process-instance').body
  end

  def start_process_instance(key:)
    @conn.post("process-definition/key/#{key}/start", {}).body
  end

  def delete_process_instance(instance)
    @conn.delete("process-instance/#{instance['id']}")
  end

  def tasks
    @conn.get('task').body
  end

  def claim_task(task, user)
    @conn.post("task/#{task['id']}/claim", userId: user['id'])
  end
end

camunda = Camunda.new

camunda.groups.each { |group| camunda.delete_group(group) }
camunda.create_group(id: 'designers', name: 'Designers', type: 'type')
camunda.create_group(id: 'recruiter', name: 'Recruiters', type: 'type')

screeners = camunda.create_group(id: 'designer_screeners', name: 'Designer screeners', type: 'type')

camunda.users.each { |user| camunda.delete_user(user) }
eldar = camunda.create_user(id: 'eldar', first_name: 'Eldar', last_name: 'Yusupov', email: 'eldar@example.com', password: 'password')

camunda.create_group_member(screeners, eldar)

camunda.process_instances.each { |instance| camunda.delete_process_instance(instance) }
camunda.deployments.each { |deployment| camunda.delete_deployment(deployment) }

camunda.create_deployment(name: 'process', file_name: 'diagram.bpmn')
camunda.start_process_instance(key: 'Process_1')

stty_save = `stty -g`.chomp
trap('INT') do
  system 'stty', stty_save
  exit
end

SUBCOMMANDS = {
  global: {
    users: '(U)sers',
    definitions: 'Process (d)efinitions',
    instances: 'Process (i)nstances',
    tasks: 'Active (t)asks'
  },
  definitions: {start: '(S)tart process instance'},
  instances: {},
  tasks: {},
  users: {},
}

GLOBAL_COMMANDS = {back: '(b)ack'}

context = :global

loop do
  commands = SUBCOMMANDS[context].merge(GLOBAL_COMMANDS)
  Readline.completion_proc = proc { |cmd| commands.keys.grep(/^#{Regexp.escape(cmd)}/) }
  Readline.completion_append_character = ''
  puts "#{commands.values.join('; ')}"
  cmd = Readline.readline("#{context}> ", true)
  break unless cmd
  cmd = cmd.to_sym

  if commands.include?(cmd)
    case cmd
    when :back
      context = :global
    else
      context = cmd
      # List entities
    end
  end
  puts cmd, "\n"
end

puts "Deployments:\n", deployments
puts "Definitions:\n", process_definitions
puts "Process instances:\n", process_instances
puts "Executions:\n", executions
puts "Tasks:\n", tasks
