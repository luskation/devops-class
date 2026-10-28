# devops-class

API em FastAPI com um endpoint `GET /hello`, empacotada em Docker e publicada no Docker Hub por um pipeline **DevSecOps** no GitHub Actions. Antes de qualquer publicação, o pipeline procura segredos, faz análise estática, varre dependências e imagem em busca de CVEs e gera o SBOM da imagem.

## Entregáveis — Trabalho Prático DevSecOps

| # | Item | Onde |
|---|------|------|
| 1 | Repositório e workflow YAML | este repositório · [`.github/workflows/devsecops.yml`](.github/workflows/devsecops.yml) |
| 2 | Execução do pipeline com as ferramentas | [Actions](https://github.com/luskation/devops-class/actions/workflows/devsecops.yml) · [Evidências](#evidências) |
| 3 | PR bloqueado + trecho do relatório | [Demonstração](#demonstração-do-bloqueio-e-da-correção) |
| 4 | Execução aprovada após a correção | [Demonstração](#demonstração-do-bloqueio-e-da-correção) |
| 5 | SBOM publicado como artifact | artifact `sbom` de cada execução (ver [Syft](#syft--sbom)) |
| 6 | Documentação | este README |

## Aplicação

- `main.py`: endpoint `GET /hello`.
- `tests/test_main.py`: testes unitários (pytest), com cobertura enviada ao SonarCloud.
- `requirements.txt`: dependências de execução com versões fixas (necessário para o Trivy identificar as versões).
- `requirements-dev.txt`: dependências de teste.
- `Dockerfile`: imagem `python:3.13-slim` com pacotes do sistema atualizados, cópia apenas do código da aplicação e execução com usuário sem privilégios (`appuser`), na porta **8000**.

## Pipeline

O workflow `DevSecOps CI/CD` executa na **abertura e atualização de Pull Requests** para a `master` (`opened`, `synchronize`, `reopened`), em **push na `master`** e manualmente (`workflow_dispatch`).

```
                 ┌─ Gitleaks (segredos) ───────────────────────┐
                 ├─ Testes unitários ─► SonarCloud (SAST + QG) ─┤
 PR / push ──────┼─ Trivy (dependências) ───────────────────────┼─► Publicar imagem no Docker Hub
                 └─ Build e teste da imagem ─┬─ Trivy (imagem) ─┤   (somente push na master)
                                             └─ Syft (SBOM) ────┘
```

| Job | Ferramenta | O que verifica | Regra de bloqueio |
|-----|-----------|----------------|-------------------|
| `Gitleaks (segredos)` | Gitleaks 8.30.1 | Todo o histórico Git (`fetch-depth: 0`) em busca de senhas, tokens e chaves | Falha com **qualquer** possível vazamento. Relatório (com valores mascarados por `--redact`) no artifact `gitleaks-report` |
| `Testes unitários` | pytest + pytest-cov | Comportamento da API e cobertura (`coverage.xml`) | Falha se algum teste falhar |
| `SonarCloud (SAST + Quality Gate)` | SonarCloud | Bugs, vulnerabilidades, *security hotspots*, code smells, duplicação e cobertura | Falha quando o **Quality Gate do código novo** reprova (`sonar.qualitygate.wait=true`) |
| `Trivy (dependências)` | Trivy 0.76.1 (`trivy fs`) | CVEs nas dependências declaradas em `requirements*.txt` | Falha com **CRITICAL ou HIGH que tenham correção** (`--ignore-unfixed`). LOW/MEDIUM só vão para o relatório |
| `Build e teste da imagem` | Docker | Build, inspeção e teste do container com `curl /hello` (etapas já existentes) | Falha se o build ou o teste falhar |
| `Trivy (imagem)` | Trivy 0.76.1 (`trivy image`) | CVEs nos pacotes do sistema operacional e Python da imagem construída | Mesma regra: bloqueia CRITICAL/HIGH com correção; LOW/MEDIUM só no relatório |
| `Syft (SBOM)` | Syft 1.55.0 | Inventário de componentes e versões da imagem | Falha se o SBOM não puder ser gerado |
| `Publicar imagem no Docker Hub` | Docker | — | Depende de **todos** os jobs acima e só roda em push na `master`; nunca roda em PR |

Detalhes de implementação:

- A imagem é construída **uma única vez**; o arquivo `image.tar` é o que o Trivy analisa, o Syft inventaria e o job de publicação envia ao Docker Hub. Assim, a imagem publicada é exatamente a verificada.
- As versões do Gitleaks, Trivy e Syft são fixas e o download é validado por **SHA-256**; as actions usadas são fixadas por **SHA do commit**. O workflow tem permissão mínima (`contents: read`).

### Trivy — registro de LOW e MEDIUM

Cada job do Trivy roda duas vezes:

1. **Relatório** com todas as severidades e `--exit-code 0`: aparece no log, no *summary* da execução e nos artifacts `trivy-deps-report` / `trivy-image-report`. Não bloqueia.
2. **Gate** com `--severity HIGH,CRITICAL --ignore-unfixed --exit-code 1`: bloqueia apenas vulnerabilidades graves para as quais já existe versão corrigida.

### SonarCloud — Quality Gate do código novo

O projeto usa o Quality Gate **Sonar way**, que avalia apenas o *New Code*:

- nenhuma nova vulnerabilidade, bug ou problema de manutenção acima do rating A;
- 100% dos *security hotspots* novos revisados;
- cobertura de código novo ≥ 80%;
- duplicação no código novo ≤ 3%.

O *New Code* é definido em **Administration → New Code** como *Reference branch* = `master`, de modo que cada PR é avaliado apenas pelo que introduz.

### Syft — SBOM

O job `Syft (SBOM)` publica o artifact **`sbom`** com três arquivos:

- `sbom.spdx.json` — formato SPDX;
- `sbom.cyclonedx.json` — formato CycloneDX;
- `sbom.txt` — tabela legível com nome, versão e tipo de cada componente.

Para baixar: **Actions → execução → Artifacts → `sbom`**.

## Configuração necessária

### Secrets do repositório (Settings → Secrets and variables → Actions)

| Secret | Uso |
|--------|-----|
| `SONAR_TOKEN` | Token gerado em SonarCloud → *My Account → Security* |
| `DOCKERHUB_USERNAME` | Usuário do Docker Hub (publicação) |
| `DOCKERHUB_TOKEN` | Access token do Docker Hub (publicação) |

### SonarCloud

1. Em [sonarcloud.io](https://sonarcloud.io), entrar com o GitHub e importar o repositório `luskation/devops-class`.
2. Conferir em **Information** se a *Organization Key* e a *Project Key* são `luskation` e `luskation_devops-class`; se forem diferentes, ajustar [`sonar-project.properties`](sonar-project.properties).
3. Em **Administration → Analysis Method**, desativar a *Automatic Analysis* (a análise é feita pelo GitHub Actions).
4. Em **Administration → New Code**, escolher *Reference branch* = `master`.
5. Em **Quality Gate**, manter o *Sonar way*.

### Proteção da branch `master` (Settings → Branches / Rules)

Criar uma regra para `master` com **Require a pull request before merging** e **Require status checks to pass**, marcando como obrigatórios:

- `Gitleaks (segredos)`
- `Testes unitários`
- `SonarCloud (SAST + Quality Gate)`
- `Trivy (dependências)`
- `Build e teste da imagem`
- `Trivy (imagem)`
- `Syft (SBOM)`

> Os checks só aparecem na lista depois de executarem pelo menos uma vez. Em repositórios privados de contas gratuitas a proteção de branch não está disponível; nesse caso o repositório precisa ser público.

## Demonstração do bloqueio e da correção

Roteiro executado em uma branch de teste, sem publicar a versão vulnerável (o job de publicação nunca roda em PR):

1. Criar a branch `teste/dependencia-vulneravel` e adicionar ao `requirements.txt` uma dependência com CVE conhecida e correção disponível:

   ```text
   requests==2.19.1
   ```

   O `requests` 2.19.1 é afetado pela **CVE-2018-18074** (HIGH — o header `Authorization` é reenviado em redirecionamentos de HTTPS para HTTP), corrigida na 2.20.0.

2. Abrir um PR para a `master`. Os jobs `Trivy (dependências)` e `Trivy (imagem)` falham e o merge fica bloqueado pela proteção de branch.

3. Corrigir para uma versão sem vulnerabilidades conhecidas e fazer push na mesma branch:

   ```text
   requests==2.34.2
   ```

4. O PR é reanalisado automaticamente e todos os checks passam.

### Evidências

| Evidência | Link / captura |
|-----------|----------------|
| PR bloqueado | _adicionar link do PR e captura_ |
| Trecho do relatório do Trivy apontando a CVE | _adicionar trecho_ |
| Execução aprovada após a correção | _adicionar link da execução e captura_ |
| Execução na `master` com publicação da imagem `3.0` | _adicionar link da execução_ |
| Artifact `sbom` | _adicionar link da execução_ |

## Como executar

```bash
# Localmente
pip install -r requirements.txt -r requirements-dev.txt
python -m pytest
uvicorn main:app --port 8000

# Imagem publicada
docker pull luskation/devops-no-ia:3.0
docker run -p 8080:8000 luskation/devops-no-ia:3.0
curl http://localhost:8080/hello
```

## Histórico — atividade anterior (Docker CI)

A versão anterior do pipeline (`docker.yml`) apenas construía, testava e publicava a imagem a cada push na `master`. Ela foi incorporada ao workflow atual nos jobs `Build e teste da imagem` e `Publicar imagem no Docker Hub`.

### Evidências da atividade anterior (Docker CI)

#### Execuções da pipeline

| Execução | Commit | Resultado | Versão publicada |
|----------|--------|-----------|------------------|
| [#2](https://github.com/luskation/devops-no-ia/actions/runs/36506478089) | `bc64dee` | ✅ success | 1.0 |
| [#5](https://github.com/luskation/devops-no-ia/actions/runs/36713886046) | `b3cf3d3` | ✅ success | 2.0 |

#### Tags no Docker Hub

| Tag | Digest |
|-----|--------|
| `1.0` | `sha256:8a23433f91e95038f4a0e4e175c9d8c4a9bed3f7aa2ea262ef1b8d334987cf13` |
| `2.0` | `sha256:14fb6f2dfa989e2a848be65db1c3142a52fd0f5ea860b5a6e39694294a61f8b9` |
| `latest` | igual à `2.0` |

#### Execução local das imagens baixadas do registry

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
