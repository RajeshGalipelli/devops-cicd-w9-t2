from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return """
    <html>
        <head>
            <title>DevOps CI/CD</title>
        </head>
        <body>
            <h1>DevOps CI/CD Application</h1>
            <h2>Version 2.0</h2>
            <p>Deployed using Jenkins, Docker and Kubernetes</p>
            <p>Status: Running - Rolling Update</p>
        </body>
    </html>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
