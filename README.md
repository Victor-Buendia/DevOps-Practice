# Trabalho individual de GCES 2022-2
|Aluno|Matrícula|
|Victor Buendia Cruz de Alvim|190020601|

# Aviso
Devido aos imprevistos com a elaboração vaga do README do Trabalho Individual, somado ao envio de informações e arquivos faltantes e necessários à elaboração do projeto ao longo dos últimos dias antes da entrega no dia 29/01/23, irei recommitar pontualmente a minha solução desenvolvida ao longo dos dias.

Farei isso para facilitar na avaliação das etapas do meu projeto, já que os commits ficaram confusos pois novas informações foram surgindo sobre o projeto em etapas que eu já imaginei ter concluído, mas não era o caso porque havia informações omitidas ou pouco claras no README.

`PORÉM, TODO HISTÓRICO DO MEU TRABALHO AINDA ESTÁ NO GITHUB.`

Também irei comentar aqui ponto a ponto sobre a solução em cada etapa, orientando-me pela tabela de avaliação:

| Item | Peso |
|---|---|
| 1. Containerização do Banco                      | 1.0 |
| 2. Containerização da biblioteca + Banco          | 1.5 |
| 3. Publicação da biblioteca  | 1.5 |
| 4. Documentação automatizada | 1.5 |
| 5. Integração Contínua (Build, Test, Lint, Documentação)       | 3.0 |
| 6. Deploy Contínuo                               | 1.5 |


## 0. Restauração do Projeto Pro Zero

Feito para iniciar a organização por commits atômicos.

---

## 1. Containerização do Banco

Criação do [docker-compose.yaml](docker-compose.yaml) com a definição do container do MongoDB.

### docker-compose.yaml
```yaml
version: '3.8'

services:
  mongodatabase:
    image: mongo:latest
    container_name: mongodatabase
    volumes:
      - ./data:/dumbdata
    restart: on-failure:3
    environment:
      MONGO_INITDB_ROOT_USERNAME: lappis
      MONGO_INITDB_ROOT_PASSWORD: l4pp1s
      MONGO_INITDB_DATABASE: metabase
    ports:
      - "27017:27017"
```

Para comprovar o funcionamento, basta executar:

```
sudo docker-compose up --remove-orphans
```
```
docker exec -it $(docker ps -f "name=mongo" -q) mongosh
```
```
use admin
```
```
db.auth('lappis','l4pp1s')
```

---

## 2. Containerização da biblioteca + Banco

Criação do [Dockerfile](Dockerfile) com a imagem para subir o container da aplicação Python. Além disso, alteração do [docker-compose.yaml](docker-compose.yaml) para a criação do container do Postgres, Metabase e da Aplicação. Também foi feita a conexão entre o Metabase com o Postgres e o MongoDB.

### docker-compose.yaml
```yaml
version: '3.8'

networks:
  netw:
    driver: bridge

services:
  mongodatabase:
    image: mongo:latest
    container_name: mongodatabase
    volumes:
      - ./data:/dumbdata
    restart: on-failure:3
    environment:
      MONGO_INITDB_ROOT_USERNAME: lappis
      MONGO_INITDB_ROOT_PASSWORD: l4pp1s
      MONGO_INITDB_DATABASE: metabase
    ports:
      - "27017:27017"
    networks:
    - netw

  metabase:
    image: metabase/metabase
    ports:
      - "3000:3000"
    environment:
      MB_DB_TYPE: postgres
      MB_DB_DBNAME: metabase
      MB_DB_PORT: 5432
      MB_DB_USER: lappis
      MB_DB_PASS: l4pp1s
      MB_DB_HOST: postgres
    depends_on:
      - postgres
      - mongodatabase
    volumes:
      - ./metabase:/metabase-data
    networks:
    - netw

  postgres:
    image: postgres
    environment:
      POSTGRES_USER: lappis
      POSTGRES_PASSWORD: l4pp1s
      POSTGRES_DB: metabase
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
    - netw

  app:
    container_name: app
    restart: on-failure:3
    build:
      context: .
      dockerfile: Dockerfile
    working_dir: /app/src
    command: python main.py
    volumes:
      - ./:/app
    depends_on:
      - mongodatabase
    ports:
      - "5000:5000"
    networks:
      - netw

volumes:
  pgdata:
```

### Dockerfile
```Dockerfile
FROM python:3.8-slim AS app
FROM python:3.8 AS build

FROM app
WORKDIR /app
COPY ./requirements.txt ./
RUN pip install --quiet --no-cache-dir -r requirements.txt

COPY . .
CMD [ "python", "/app/src/main.py" ]
```

Para comprovar o funcionamento, basta executar:

```
sudo docker-compose up --remove-orphans
```

Vamos inserar os dados fake dentro do nosso MongoDB importando o CSV [vaccination-data.csv](data/vaccination-data.csv). Execute o comando abaixo:

```
docker exec -it $(docker ps -f "name=mongo" -q) mongoimport --drop --authenticationDatabase=admin -u=lappis -p=l4pp1s  --host=mongodatabase --db="gces" --collection="vaccination" --type=csv --headerline --file=/dumbdata/vaccination-data.csv
```

Acessar `http://localhost:3000/` e configurar o metabase, se atentando aos seguintes campos na etapa **Add your data**:

- `Database:` MongoDB
- `Display name:` \<qualquer-mome\>
- `Host:` mongodatabase
- `Database name:` gces
- `Port:` 27017
- `Username:` lappis
- `Password:` l4pp1s

Os campos listados acima precisam ser obrigatoriamente os elencados para que a conexão com o MongoDB seja bem sucedida.

Com isso feito, já vai ser possível ver a collection com os dados fake no Metabase.

---

## 3. Publicação da biblioteca

Nesta etapa a pasta [gces-bib](gces-bib) é criada para gerar o build dos pacotes do projeto usando o poetry. Os seguintes comandos foram executados para gerá-la:

```
poetry new gces-bib
```

```
cd gces-bib
```

O comando abaixo serve para adicionar todas as dependências do projeto no arquivo [poetry.lock](gces-bib/poetry.lock).
```
poetry add $(cat ../requirements.txt)
```

O comando abaixo gera a biblioteca das dependências.
```
poetry build
```

Os dois comandos abaixo são para configurar o token do PyPi e publicar a biblioteca no Pypi.
```
poetry config pypi-token.pypi <TOKEN>
```

```
poetry publish --skip-existing
```

Para comprovar que houve sucesso no processo, basta acessar o link abaixo para ver a biblioteca publicada:

### Link da Biblioteca Publicada
https://pypi.org/project/gces-bib/

Também é possível atestar o sucesso ao executar o seguinte comando:

```
pip3 install gces-bib
```

---

## 4. Documentação automatizada

Nesta etapa, é preciso usar o Doxygen, Sphinx e Breathe para gerar a documentação.

Primeiro é preciso instalar o Doxygen:

```bash
git clone https://github.com/doxygen/doxygen.git
cd doxygen
mkdir build
cd build
cmake -G "Unix Makefiles" ..
make
make install
```

Depois, criamos um arquivo [Doxyfile](Doxyfile) e editamos ele para ficar da maneira que ficou no repositório:

```
doxygen -g
sudo nano Doxyfile
```

Por fim, geramos a documentação em XML executando:

```
doxygen Doxyfile
```

Já é possível ver nossa documentação automatizada no [/docs/html/index.html](docs/html/index.html) feita pelo Doxygen.

Agora, temos que instalar o Sphinx e o Breathe executando:

```
pip3 install breathe sphinx
```

Depois, damos um *start* no Sphinx dentro da pasta source e configuramos os arquivos [conf.py](docs/conf.py) e [index.rst](docs/index.rst) para integrar com o Breathe que instalamos também.

```
sphinx-quickstart
```

No arquivo [conf.py](docs/conf.py), é importante configurar a extensão do Breathe.

```py
# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'GCES'
copyright = '2023, Victor Buendia'
author = 'Victor Buendia'
release = '1.0.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = ['breathe']

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

breathe_projects = {
    "GCES": "../docs/xml",
}

breathe_default_project = "GCES"

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'alabaster'
html_static_path = ['_static']

```

Já no arquivo [index.rst](docs/index.rst), é preciso adicionar `.. doxygenindex::` no início do arquivo.

```rst
.. GCES documentation master file, created by
   sphinx-quickstart on Sat Jan 28 17:59:24 2023.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to GCES's documentation!
================================

.. doxygenindex::


.. toctree::
   :maxdepth: 2
   :caption: Contents:



Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
```

Com tudo isso configurado, basta rodar o build do nosso Sphinx integrado com o Breathe.

```
sphinx-build -b html ./docs _build  
```

Já é possível ver nossa documentação automatizada no [/\_build/index.html](_build/index.html) feita pelo Sphinx, Breathe com o XML do Doxygen.

---

## 5. Integração Contínua (Build, Test, Lint, documentacao)

## 6. Deploy Contínuo