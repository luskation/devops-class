# devops-class

API em FastAPI com um endpoint `GET /hello`, empacotada em Docker e publicada no Docker Hub por uma pipeline do GitHub Actions a cada push na branch `master`.

## Entregáveis

| # | Item | Onde |
|---|------|------|
| 1 | Repositório | https://github.com/luskation/devops-no-ia |
| 2 | Dockerfile | [`Dockerfile`](Dockerfile) |
| 3 | Pipeline | [`.github/workflows/docker.yml`](.github/workflows/docker.yml) |
| 4 | Execuções da pipeline | https://github.com/luskation/devops-no-ia/actions |
| 5 | Imagem no registry | [`luskation/devops-no-ia`](https://hub.docker.com/r/luskation/devops-no-ia/tags) (tags `1.0`, `2.0`, `latest`) |
| 6 e 7 | Versões 1.0 e 2.0 rodando localmente | [Evidências](#evidências) |

## Aplicação

- `main.py`: endpoint `GET /hello`.
- `requirements.txt`: dependências (FastAPI e Uvicorn).
- `Dockerfile`: imagem baseada em `python:3.11-slim`, servindo a aplicação com Uvicorn na porta **8000**.

## Pipeline

O workflow `Docker CI` roda a cada push na `master` e executa, em ordem:

1. **Checkout** do código.
2. **Build** da imagem com duas tags: a versão (`IMAGE_VERSION`) e `latest`.
3. **Verificação** de que a imagem foi criada.
4. **Teste**: sobe o container e faz `curl` em `/hello`. Se falhar, a pipeline para antes de publicar.
5. **Login** no Docker Hub com os secrets `DOCKERHUB_USERNAME` e `DOCKERHUB_TOKEN`.
6. **Push** das tags de versão e `latest`.

Para gerar uma nova versão, basta alterar `IMAGE_VERSION` no workflow e fazer push.

## Evidências

### Execuções da pipeline

| Execução | Commit | Resultado | Versão publicada |
|----------|--------|-----------|------------------|
| [#2](https://github.com/luskation/devops-no-ia/actions/runs/36506478089) | `bc64dee` | ✅ success | 1.0 |
| [#5](https://github.com/luskation/devops-no-ia/actions/runs/36713886046) | `b3cf3d3` | ✅ success | 2.0 |

### Tags no Docker Hub

| Tag | Digest |
|-----|--------|
| `1.0` | `sha256:8a23433f91e95038f4a0e4e175c9d8c4a9bed3f7aa2ea262ef1b8d334987cf13` |
| `2.0` | `sha256:14fb6f2dfa989e2a848be65db1c3142a52fd0f5ea860b5a6e39694294a61f8b9` |
| `latest` | igual à `2.0` |

### Execução local das imagens baixadas do registry

Antes de cada teste, a imagem local foi removida, para garantir que o `docker pull` baixasse a imagem do Docker Hub.

> A aplicação escuta na porta 8000 dentro do container. Por isso o mapeamento é `-p 8080:8000`.

**Versão 1.0: `Hello World`**

```console
$ docker pull luskation/devops-no-ia:1.0
Digest: sha256:8a23433f91e95038f4a0e4e175c9d8c4a9bed3f7aa2ea262ef1b8d334987cf13
Status: Downloaded newer image for luskation/devops-no-ia:1.0

$ docker run -d -p 8080:8000 luskation/devops-no-ia:1.0
8be3b7d52e72

$ curl http://localhost:8080/hello
{"message":"Hello World"}
```

**Versão 2.0: `Hello World 2`**

```console
$ docker pull luskation/devops-no-ia:2.0
Digest: sha256:14fb6f2dfa989e2a848be65db1c3142a52fd0f5ea860b5a6e39694294a61f8b9
Status: Downloaded newer image for luskation/devops-no-ia:2.0

$ docker run -d -p 8080:8000 luskation/devops-no-ia:2.0
6f607d53b462

$ curl http://localhost:8080/hello
{"message":"Hello World 2"}
```

## Como executar

```bash
docker pull luskation/devops-no-ia:2.0
docker run -p 8080:8000 luskation/devops-no-ia:2.0
curl http://localhost:8080/hello
```
