from flask import Flask, render_template, request, redirect, url_for
from models.contato import Contato
from models.plano import Plano

app = Flask(__name__)

@app.route("/")
def home():
    return render_template("home.html")

@app.route("/planos")
def planos():
    planos_ativos = Plano.listar_ativos()
    return render_template("planos.html", planos=planos_ativos)

@app.route("/contato", methods=["GET", "POST"])
def contato():
    erro = None

    if request.method == "POST":
        resultado = Contato.incluir(request.form.to_dict())

        if resultado["sucesso"]:
            return redirect(url_for("contato", enviado=1))

        erro = resultado["erro"]

    return render_template(
        "contato.html",
        erro=erro,
        enviado=request.args.get("enviado") == "1"
    )


if __name__ == "__main__":
    print(app.url_map)
    app.run(host="0.0.0.0", port=5155, debug=True)