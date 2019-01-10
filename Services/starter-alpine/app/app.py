from flask import Flask, request, render_template
 
app = Flask(__name__)
 
 
@app.route('/')
def hello():
    return "Hello, World!\n This is a test."


@app.route('/echo')
def echo():
    echodat = request.args.get('echo', default = 'NOTHING', type = str)
    return ("You passed in " + echodat + " to echo.")


if __name__ == '__main__':
    app.run(debug=True)

