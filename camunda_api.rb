module Connection
  BASE_URL = 'http://localhost:8080/engine-rest/'.freeze
  DEBUG = false

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |faraday|
      faraday.request  :multipart
      faraday.request  :json

      faraday.adapter  Faraday.default_adapter

      faraday.response :json, content_type:  /\bjson$/
      faraday.response :raise_error
      faraday.response :logger if DEBUG
    end
  end
end

class Resource
  def initialize(options = {})
    options.keys.each { |attr| instance_variable_set("@#{attr}", options[attr]) }
  end

  def parse_body(body)
    attributes.each do |attr|
      keys = attr.to_s.split('_')
      key = keys.first.downcase + keys.drop(1).collect(&:capitalize).join
      instance_variable_set("@#{attr}", body[key])
    end
    self
  end

  private

  def self.attr_accessor(*vars)
    @attributes ||= []
    @attributes.concat vars
    super(*vars)
  end

  def self.attr_reader(*vars)
    @attributes ||= []
    @attributes.concat vars
    super(*vars)
  end

  def self.attr_writer(*vars)
    @attributes ||= []
    @attributes.concat vars
    super(*vars)
  end

  def self.attributes # rubocop:disable Style/TrivialAccessors
    @attributes
  end

  def attributes
    self.class.attributes
  end

  def to_s
    values = attributes.map { |attr| [attr, instance_variable_get("@#{attr}")].join(': ') }.join('; ')
    "#{self.class} <#{values}>"
  end
end

class Group < Resource
  include Connection

  attr_accessor :id, :name, :type

  def delete
    connection.delete("group/#{id}")
  end

  def create
    connection.post('group/create', id: id, name: name, type: type)
    self
  end

  def update
    connection.post("group/#{id}", id: id, name: name, type: type)
    self
  end
end

class User < Resource
  include Connection

  attr_accessor :id, :first_name, :last_name, :email
  attr_writer :password

  def delete
    connection.delete("user/#{id}")
  end

  def create
    profile = {id: id, firstName: first_name, lastName: last_name, email: email}
    credentials = {password: @password}
    connection.post('user/create',
                    profile: profile,
                    credentials: credentials)
    self
  end

  def add_to_group(group)
    connection.put("group/#{group.id}/members/#{id}")
    self
  end
end

class Deployment < Resource
  include Connection

  attr_reader :id
  attr_accessor :name

  def create(file_name:)
    file = Faraday::UploadIO.new(file_name, 'text/xml')
    response = connection.post('deployment/create', 'deployment-name': name, file: file).body
    @id = response['id']
  end

  def delete
    connection.delete("deployment/#{id}")
  end
end

class Execution < Resource
  include Connection

  attr_reader :id
  attr_accessor :process_instance_id, :ended
end

class ProcessDefinition < Resource
  include Connection

  attr_reader :id, :key, :category, :description, :name, :version, :resource, :deployment_id, :diagram, :suspended

  def start
    connection.post("process-definition/key/#{key}/start", {}).body
  end
end

class ProcessInstance < Resource
  include Connection

  attr_reader :id, :definition_id, :business_key, :case_instance_id, :ended, :suspended

  def delete
    connection.delete("process-instance/#{id}")
  end
end

class TaskDefinition < Resource
  include Connection
end

class Task < Resource
  include Connection

  attr_reader :id, :name, :assignee, :created, :due, :follow_up,
              :delegation_state, :description, :execution_id, :owner,
              :parent_task_id, :priority, :process_definition_id,
              :process_instance_id, :case_execution_id, :case_definition_id,
              :case_instance_id, :task_definition_key

  def claim(user)
    connection.post("task/#{id}/claim", userId: user['id'])
  end
end

class Filter < Resource
  include Connection

  attr_reader :id, :resource_type, :name, :owner, :query, :properties, :item_count

  def create
    result = connection.post('filter/create', id: id, resourceType: resource_type, name: name, owner: owner, query: query, properties: properties, itemCount: item_count) 
    self
  end

  def delete
    connection.delete("filter/#{id}")
  end
end

class Camunda
  include Connection

  def groups
    connection.get('group').body.map do |group|
      Group.new.parse_body(group)
    end
  end

  def users
    connection.get('user').body.map do |user|
      User.new.parse_body(user)
    end
  end

  def deployments
    connection.get('deployment').body.map { |deployment| Deployment.new.parse_body(deployment) }
  end

  def executions
    connection.get('execution').body.map { |execution| Execution.new.parse_body(execution) }
  end

  def process_definitions
    connection.get('process-definition').body.map { |definition| ProcessDefinition.new.parse_body(definition) }
  end

  def process_instances
    connection.get('process-instance').body.map { |instance| ProcessInstance.new.parse_body(instance) }
  end

  def tasks
    connection.get('task').body.map { |task| Task.new.parse_body(task) }
  end

  def filters
    connection.get('filter').body.map { |filter| Filter.new.parse_body(filter) }
  end
end
