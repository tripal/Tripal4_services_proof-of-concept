from flask import Flask, render_template
 
app = Flask(__name__)
 
 
@app.route('/')
def hello():
    return "Hello, World!\n"
    
# Create list of content types from Chado
# Tell Drupal about it

# Designed full route: /entity/{version}/{entity_type}/{entity_id}/{field_name}
@app.route('/entity/<version>/<int:entity_type>/<int:entity_id>/<field_name>/')
def entity(version, entity_type, entity_id,field_name):
    echostring = version
    return echostring

 
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5005)



    

