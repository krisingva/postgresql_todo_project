require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "todos")
    end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info("#{statement}: #{params}")
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1"
    result = query(sql, id)

    tuple = result.first
    list_id = tuple["id"].to_i
    todos = find_todos_for_list(list_id)
    {id: list_id, name: tuple["name"], todos: todos}

    # todos: array will have hash items:
    # { id: id, name: todo_name, completed: false, list_id: list_id }
  end

  def all_lists
    sql = "SELECT * FROM lists"
    result = query(sql)
    # before we had a list represented as:
    # [{id:, name:, todos: }]
    result.map do |tuple|
      list_id = tuple["id"].to_i
      todos = find_todos_for_list(list_id)
      {id: list_id, name: tuple["name"], todos: todos}
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, list_name)
  end

  def delete_list(id)
    todos_sql = "DELETE FROM todos WHERE list_id = ($1);"
    list_sql = "DELETE FROM lists WHERE id = ($1);"
    query(todos_sql, id)
    query(list_sql, id)
  end

  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $2 WHERE id = $1;"
    query(sql, id, new_name)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2);"
    query(sql, todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2"
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $3 WHERE id = $2 AND list_id = $1;"
    query(sql, list_id, todo_id, new_status)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1;"
    query(sql, list_id)
  end

  private

  def find_todos_for_list(list_id)
    todo_sql = "SELECT * FROM todos WHERE list_id = $1"
    todos_result = query(todo_sql, list_id)

    todos_result.map do |todo_tuple|
      { id: todo_tuple["id"].to_i,
        name: todo_tuple["name"],
        completed: todo_tuple["completed"] == "t"}
    # todos will now become an array of hashes where each line from the todos_result forms a hash
    end
  end
end
