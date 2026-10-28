from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_hello_retorna_mensagem():
  response = client.get("/hello")
  assert response.status_code == 200
  assert response.json() == {"message": "Hello World 2"}


def test_rota_inexistente_retorna_404():
  response = client.get("/nao-existe")
  assert response.status_code == 404
