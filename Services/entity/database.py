import json
import psycopg2

def get_tripal_connection():
    conn = ''

    try:
        conn = psycopg2.connect(dbname = 'tripal_user', user = 'tripal_user', host = 'tripal4_tripal4_db_1', password = 'example')
    except Exception as e:
        print("Error in SQL:\n", e)
    return conn

def get_tripal_db_data():
    db = get_tripal_connection()
    try:
        sqlstr = "SELECT * FROM entity LIMIT 5"
        cur = db.cursor()
        cur.execute(sqlstr)
        output_json = cur.fetchall()
    except Exception as e:
        print("Error in SQL:\n", e)
    return output_json


def getMysqlConnection(dbname, user, host, password):
  print("getMysqlConnection");
  conn = ''
  try:
    conn = psycopg2.connect(dbname = dbname, user = user, host = host, password = password)
  except Exception as e:
    print("Error in SQL:\n", e)
  return conn


def get_db_data(dbname, user, host, password, table):
  db = getMysqlConnection(dbname, user, host, password)
  output_json = ''
  try:
    sqlstr = 'SELECT * FROM ' + table + ' LIMIT 5'
    cur = db.cursor()
    cur.execute(sqlstr)
    output_json = cur.fetchall()
  except Exception as e:
    print("Error in SQL:\n", e)
  return output_json


#
# These would normally be populated by querying the database, but we'll just fudge some
# data
#

# An exact and exhausting list of entity types
entity_types = ["organism","analysis","project"];

# List of entities of each type
organism_entities = ["organism_1","organism_2"]
analysis_entities = ["analysis_1","analysis_2"]
project_entities = ["project_1","project_2"]

# List all entities types
def list_entity_types():
  #return "list_of_entities from version %s" % version
  return json.dumps(entity_types)

# List all entities of a certain type
def list_entities_by_type(entity_type):

# List
    if (entity_type == 1):
        return json.dumps(organism_entities)
    elif (entity_type == 2):
        return json.dumps(analysis_entities)
    elif (entity_type == 3):
        return json.dumps(project_entities)

# List single entity
def list_entity(entity_type, entity_id):
  try:
    if (entity_type == 1):
        return json.dumps(organism_entities[entity_id])
    elif (entity_type == 2):
        return json.dumps(analysis_entities[entity_id])
    elif (entity_type == 3):
        return json.dumps(project_entities[entity_id])
  except IndexError:
      return 'Entity does not exist'

# List field data for a specific entity
def list_entity_field_data(entity_type, entity_id, field_name):
    return "placeholder\n"
