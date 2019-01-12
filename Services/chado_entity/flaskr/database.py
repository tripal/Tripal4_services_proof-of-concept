import json
import psycopg2

def getMysqlConnection():
  print("getMysqlConnection");
  conn = ''
  try:
    conn = psycopg2.connect("dbname='chado_user' user='chado_user' host='chado_chado_db_1' password='example'")
  except Exception as e:
    print("Error in SQL:\n", e)
  return conn


def get_db_data():
  db = getMysqlConnection()
  output_json = ''
  try:
    sqlstr = "SELECT * from chado.feature limit 5"
    cur = db.cursor()
    cur.execute(sqlstr)
    output_json = json.dumps(cur.fetchall())
  except Exception as e:
    print("Error in SQL:\n", e)
  return output_json

#================================================================#
# These would normally be populated by querying the database, but we'll just fudge some
# data

# An exact and exhausting list of entity types
entity_types = ["organism","analysis","project"];

# List of entities of each type
organism_entities = ["organism_1","organism_2"]
analysis_entities = ["analysis_1","analysis_2"]
project_entities = ["project_1","project_2"]

organism_fields = [] 

# List all entities of a certain type
def list_entities_by_type(entity_type): 
    # List 
    if (entity_type == 1):
        return json.dumps(organism_entities)
    elif (entity_type == 2):
        return json.dumps(analysis_entities)
    elif (entity_type == 3):
        return json.dumps(project_entities)

# List field data for a specific entity
def list_entity_fields(entity_type, entity_id, field_name):
    return "placeholder\n"
