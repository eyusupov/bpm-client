module Connection
  BASE_URL = 'http://localhost:8080/bpm-sample/'.freeze
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

class Group
  include Connection

  attr_accessor :id, :name, :type

  def initialize(id:, name:, type:)
    @id = id
    @name = name
    @type = type
  end

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

class User
  include Connection

  attr_accessor :id, :first_name, :last_name, :email

  def initialize(id:, first_name:, last_name:, email:, password: nil)
    @id = id
    @first_name = first_name
    @last_name = last_name
    @email = email
    @password = password
  end

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
  end
end

class Deployment
  include Connection

  attr_reader :id
  attr_accessor :name

  def initialize(id: nil, name:)
    @id = id
    @name = name
  end

  def create(file_name:)
    file = Faraday::UploadIO.new(file_name, 'text/xml')
    response = connection.post('deployment/create', 'deployment-name': name, file: file).body
    @id = response['id']
  end

  def delete
    connection.delete("deployment/#{id}")
  end
end

class Execution
  include Connection

  attr_reader :id
  attr_accessor :process_insance_id, :ended

  def initialize(id:, process_instance_id:, ended:)
  end
end

class ProcessDefinition
  include Connection

  attr_reader :id, :key, :category, :description, :name, :version, :resource, :deployment_id, :diagram, :suspended

  def initialize(id:, key:, category:, description:, name:, version:, resource:, deployment_id:, diagram:, suspended:)
    @id = id
    @key = key
    @category = category
    @description = description
    @name = name
    @version = version
    @resource = resource
    @deployment_id = deployment_id
    @diagram = diagram
    @suspended = suspended
  end

  def start
    connection.post("process-definition/key/#{key}/start", {}).body
  end
end

class ProcessInstance
  include Connection

  attr_reader :id, :definition_id, :business_key, :case_instance_id, :ended, :suspended

  def initialize(id:, definition_id:, business_key:, case_instance_id:, ended:, suspended:)
    @id = id
    @definition_id = definition_id
    @business_key = business_key
    @case_instance_id = case_instance_id
    @ended = ended
    @suspended = suspended
  end

  def delete
    connection.delete("process-instance/#{id}")
  end
end

class Task
  include Connection

  attr_reader :id, :name, :assignee, :created, :due, :follow_up,
              :delegation_state, :description, :execution_id, :owner,
              :parent_task_id, :priority, :process_definition_id,
              :process_instance_id, :case_execution_id, :case_definition_id,
              :case_instance_id, :task_definition_key

  def initialize(id:, name:, assignee:, created:, due:,
                 follow_up:, delegation_state:, description:,
                 execution_id:, owner:, parent_task_id:,
                 priority:, process_definition_id:,
                 process_instance_id:, case_execution_id:,
                 case_definition_id:, case_instance_id:,
                 task_definition_key:)
    @id = id
    @name = name
    @assignee = assignee
    @created = created
    @due = due
    @follow_up = follow_up
    @delegation_state = delegation_state
    @description = description
    @execution_id = execution_id
    @owner = owner
    @parent_task_id = parent_task_id
    @priority = priority
    @process_definition_id = process_definition_id
    @process_instance_id = process_instance_id
    @case_execution_id = case_execution_id
    @case_definition_id = case_definition_id
    @case_instance_id = case_instance_id
    @task_definition_key = task_definition_key
  end

  def claim(user)
    connection.post("task/#{id}/claim", userId: user['id'])
  end
end

class Camunda
  include Connection

  def groups
    connection.get('group').body.map do |group|
      Group.new(id: group['id'],
                name: group['name'],
                type: group['type'])
    end
  end

  def users
    connection.get('user').body.map do |user|
      User.new(id: user['id'],
               first_name: user['firstName'],
               last_name: user['lastName'],
               email: user['email'])
    end
  end

  def deployments
    connection.get('deployment').body.map do |deployment|
      Deployment.new(id: deployment['id'], name: deployment['name'])
    end
  end

  def executions
    connection.get('execution').body.map do |execution|
      Execution.new(id: execution['id'], process_instance_id: execution['processInstanceId'], ended: execution['ended'])
    end
  end

  def process_definitions
    connection.get('process-definition').body.map do |definition|
      ProcessDefinition.new(id: definition['id'],
                            key: definition['key'],
                            category: definition['category'],
                            description: definition['description'],
                            name: definition['name'],
                            version: definition['version'],
                            resource: definition['resource'],
                            deployment_id: definition['deployment_id'],
                            diagram: definition['diagram'],
                            suspended: definition['suspended'])
    end
  end

  def process_instances
    connection.get('process-instance').body.map do |instance|
      ProcessInstance.new(id: instance['id'],
                          definition_id: instance['definitionId'],
                          business_key: instance['businessKey'],
                          case_instance_id: instance['caseInstanceId'],
                          ended: instance['ended'],
                          suspended: instance['suspended'])
    end
  end

  def tasks
    connection.get('task').body.map do |task|
      Task.new(id: task['id'],
               name: task['name'],
               assignee: task['assignee'],
               created: task['created'],
               due: task['due'],
               follow_up: task['followUp'],
               delegation_state: task['delegationState'],
               description: task['description'],
               execution_id: task['executionId'],
               owner: task['owner'],
               parent_task_id: task['parentTaskId'],
               priority: task['priority'],
               process_definition_id: task['processDefinitionId'],
               process_instance_id: task['processInstanceid'],
               case_execution_id: task['caseExecutionId'],
               case_definition_id: task['caseDefinitionId'],
               case_instance_id: task['caseInstanceid'],
               task_definition_key: task['taskDefinitionKey'])
    end
  end
end
