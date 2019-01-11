from flask import Flask, render_template

app = Flask(__name__)


@app.route('/')
def hello():
    return "Hello, World!\n"

# Create list of content types from Chado
# Tell Drupal about it

# Designed full route: /entity/{version}
@app.route('/entity/<version>/')
def get_content_types(version):
    return version

# Designed full route: /entity/{version}/{entity_type}
@app.route('/entity/<version>/<int:entity_type>/')
def get_entities_by_type(version, entity_type):
    return str(entity_type)

# Designed full route: /entity/{version}/{entity_type}/{entity_id}
@app.route('/entity/<version>/<int:entity_type>/<int:entity_id>/')
def get_entity(version, entity_type, entity_id):
    return str(entity_id)

# Designed full route: /entity/{version}/{entity_type}/{entity_id}/{field_name}
@app.route('/entity/<version>/<int:entity_type>/<int:entity_id>/<field_name>/')
def get_entity_field_data(version, entity_type, entity_id, field_name):
    return field_name

@app.route('/import/entities/<provider>/<int:entity_type>', methods=['POST'])
def post_entity(provider, entity_type):
    return "placeholder\n"

@app.route('/import/fields/<int:entity_type>', methods=['POST'])
def post_entity_fields(entity_type):
    return "placeholder\n"


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5005)
