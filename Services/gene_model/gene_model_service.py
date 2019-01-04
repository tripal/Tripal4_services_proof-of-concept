from flask import Flask, render_template, request, json
 
app = Flask(__name__)
 
 
@app.route('/')
def hello():
  return "This is the gene model service\n"

@app.route('/search/gene_model', methods=['POST','GET'])
def search():
  term = getParam('term')
  if request.method == 'GET':
    print("Process GET request")
    if len(request.args.getlist('term')) > 0:
      term = request.args.getlist('term')[0]
      
  else:  # request method is POST
    print("Process POST request")
    if request.is_json:
      content = request.get_json(silent=True)
      term = content.get('term', '')
    else:
      if len(request.args.getlist('term')) > 0:
        term = request.args.getlist('term')[0]
    
  return getGeneModelList(term)


@app.route('/record/gene_model', methods=['POST','GET'])
def record():
  gene_model = getParam('gene_model', '')
  d = getGeneModelData(gene_model)
  if d:
    return d;
  else:
    return "No gene model id was provided"
    

@app.errorhandler(404)
def page_not_found(error):
  return 'This endpoint does not exist\n', 404
  
    
def getGeneModelData(gene_model):
  if gene_model == '':
    return False;
  else:
    dummy_record = {'gene_model' : gene_model,
                    'description' : 'a super important gene'}
    return json.dumps(dummy_record)
  
  
def getGeneModelList(term):
  dummy_list = [{'gene_model' : 'gene_model1'}, 
                {'gene_model' : 'gene_model2'},
                {'gene_model' : 'gene_model3'}]
  return json.dumps(dummy_list)


def getParam(param, default=''):
  val = default
  if request.method == 'GET':
    print("Process GET request")
    if len(request.args.getlist(param)) > 0:
      val = request.args.getlist(param)[0]
      
  else:  # request method is POST
    print("Process POST request")
    if request.is_json:
      content = request.get_json(silent=True)
      val = content.get(param, '')
    else:
      if len(request.args.getlist(param)) > 0:
        val = request.args.getlist(param)[0]
        
  return val


if __name__ == '__main__':
  app.run(debug=True, host='0.0.0.0', port=6000)

