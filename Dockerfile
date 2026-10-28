FROM python:3.11-slim

WORKDIR /app

# Aplica as correções de segurança disponíveis para os pacotes do sistema
RUN apt-get update && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# Instala as dependências e remove o pip, setuptools e wheel, que não são usados
# em execução e trazem bibliotecas com vulnerabilidades conhecidas
RUN pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y pip setuptools wheel \
    && rm -rf /usr/local/lib/python3.11/ensurepip

COPY main.py .

# Executa a aplicação sem privilégios de root
RUN useradd --create-home --uid 10001 app
USER app

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
