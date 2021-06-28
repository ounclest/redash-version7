FROM node:10.15.3-alpine as frontend-builder

WORKDIR /frontend
COPY package.json package-lock.json /frontend/
#RUN npm cache clear --force
#RUN npm install --save caniuse-lite browserslist
RUN npm install

COPY . /frontend

RUN npm run build

FROM ubuntu:18.04

RUN useradd --create-home redash

# Ubuntu packages
RUN apt-get update && apt-get install -y gcc g++ make curl && curl https://deb.nodesource.com/setup_10.x | bash - && \
  apt-get install -y python-setuptools-scm python-typing python-pip python-pytest-runner python-dev python-cassandra build-essential pwgen libffi-dev sudo git-core wget unzip \
  nodejs \
  # Postgres client
  libpq-dev \
  # for SAML
  xmlsec1 \
  # Additional packages required for data sources:
  libaio1 libssl-dev libmysqlclient-dev freetds-dev libsasl2-dev && \

  apt-get clean && \
  rm -rf /var/lib/apt/lists/*


RUN pip install -U setuptools==21.1.0

RUN pip install cassandra-driver --install-option="--no-cython"

WORKDIR /app

# Controls whether to install extra dependencies needed for all data sources.
ARG skip_ds_deps

# We first copy only the requirements file, to avoid rebuilding on every file
# change.
COPY requirements.txt requirements_dev.txt requirements_all_ds.txt ./
RUN pip install -r requirements.txt -r requirements_dev.txt

# RUN if [ "x$skip_ds_deps" = "x" ] ; then pip install -r requirements_all_ds.txt ; else echo "Skipping pip install -r requirements_all_ds.txt" ; fi

COPY . /app
COPY --from=frontend-builder /frontend/client/dist /app/client/dist
RUN chown -R redash /app
USER redash

ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["server"]
