from flask import Flask, render_template,  request, json
from database import *

app = Flask(__name__)


@app.route('/')
def hello():
    return "Hello, World!\n"

# Create list of content types from Chado
# Tell Drupal about it

@app.route('/entity_data/', methods=['GET'])
def get_content_from_db():
    return str(get_db_data())

# Designed full route: /entity/{version}
@app.route('/entity/<version>/', methods=['GET'])
def get_content_types(version):
    return version

# Designed full route: /entity/{version}/{entity_type}
@app.route('/entity/<version>/<int:entity_type>/', methods=['GET'])
def get_entities_by_type(version, entity_type):
    return list_entities_by_type(entity_type)

# Designed full route: /entity/{version}/{entity_type}/{entity_id}
@app.route('/entity/<version>/<int:entity_type>/<int:entity_id>/', methods=['GET'])
def get_entity(version, entity_type, entity_id):
    return list_entity(entity_type, entity_id)

# Designed full route: /entity/{version}/{entity_type}/{entity_id}/{field_name}
@app.route('/entity/<version>/<int:entity_type>/<int:entity_id>/<field_name>/', methods=['GET'])
def get_entity_field_data(version, entity_type, entity_id, field_name):
    return list_entity_field_data(entity_type, entity_id, field_name)

@app.route('/import/entities/<provider>/<int:entity_type>', methods=['POST'])
def post_entity(provider, entity_type):
    return "placeholder\n"

@app.route('/import/fields/<int:entity_type>', methods=['POST'])
def post_entity_fields(entity_type):
    return "placeholder\n"

@app.errorhandler(404)
def page_not_found(error):
  return 'This endpoint does not exist\n', 404


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5005)
