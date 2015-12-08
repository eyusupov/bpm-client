#!/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'pry'
require 'faraday'
require 'faraday_middleware'
require 'readline'

require_relative 'camunda_api'

camunda = Camunda.new

camunda.groups.each(&:delete)
Group.new(id: 'designers', name: 'Designers', type: 'type').create
Group.new(id: 'recruiter', name: 'Recruiters', type: 'type').create

screeners = Group.new(id: 'designer_screeners', name: 'Designer screeners', type: 'type').create

camunda.users.each(&:delete)
eldar = User.new(id: 'eldar', first_name: 'Eldar', last_name: 'Yusupov', email: 'eldar@example.com', password: 'password').create

eldar.add_to_group(screeners)

camunda.process_instances.each(&:delete)
camunda.deployments.each(&:delete)

Deployment.new(name: 'process').create(file_name: 'diagram.bpmn')
camunda.process_definitions.each(&:start)

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
