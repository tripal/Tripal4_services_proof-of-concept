from flask import Flask, render_template,  request, json
from database import *

app = Flask(__name__)

@app.route('/')
def hello():
    return "This is the chado entity service!\n"

# /entity_type/{version}/{entity_type}
# Responds with a list of entities for the given type. It responds with the array [id, label]
@app.route('/entity_type/<version>/<int:entity_type>/', methods=['GET'])
def get_entities_by_type(version, entity_type):
    return list_entities_by_type(entity_type)

# /entity_type/{version}/{entity_type}/{fields}
# Responds with an array compatible with the TripalField::element_info() array.
@app.route('/entity_type/<version>/<int:entity_type>/<int:fields>/', methods=['GET'])
def get_entity_fields(version, entity_type, entity_id, field_name):
    return list_entity_fields(entity_type, entity_id, field_name)

# test the connection to the chado db
@app.route('/entity_data/', methods=['GET'])
def get_content_from_db():
    return str(get_db_data())

@app.errorhandler(404)
def page_not_found(error):
  return 'This endpoint does not exist\n', 404


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5005)
