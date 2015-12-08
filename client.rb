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
  global: [:groups, :users, :process_definitions, :process_instances, :tasks]
}
COMMON_SUBCOMMANDS = [:back]

context = :global

loop do
  commands = SUBCOMMANDS[context] || []
  commands.push(*COMMON_SUBCOMMANDS) unless context == :global
  Readline.completion_proc = proc { |cmd| commands.grep(/^#{Regexp.escape(cmd)}/) }
  Readline.completion_append_character = ''
  puts "#{commands.join('; ')}"
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
      entities = camunda.send(cmd)
      entities.each { |entity| puts entity }
    end
  end
end
