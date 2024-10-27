FROM python:3.12.7-bookworm

# Set up iff pip repo sources
ENV PIP_EXTRA_INDEX_URL="https://gitlab.com/api/v4/groups/13299895/-/packages/pypi/simple https://gitlab.com/api/v4/groups/81763890/-/packages/pypi/simple"
RUN pip config set global.trusted-host gitlab.com
RUN sh -c 'pip config set global.extra-index-url "$PIP_EXTRA_INDEX_URL"'

# Set the working directory in the container
WORKDIR /semester_project

COPY . /semester_project

RUN git config --global http.sslVerify false

RUN --mount=type=secret,id=netrc,dst=/kaniko/.netrc echo Install dependencies\
     && mkdir -p /root/ \
     && ln -s /kaniko/.netrc /root/.netrc 2>/dev/null || : \
     && python -m pip install --upgrade pip \
     && pip install -r requirements.txt


# Install wget and other necessary system packages
RUN apt-get update && apt-get install -y wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get install -y curl

# Install poetry
RUN curl -sSL https://install.python-poetry.org | python -
ENV PATH="/semester_project/.local/bin:$PATH"
RUN poetry install

# Download Miniconda installer script
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /miniconda.sh

# Install Miniconda
RUN bash /miniconda.sh -b -p /opt/conda

# Add Conda to Path
ENV PATH=/opt/conda/bin:$PATH

# Specify where to create the Conda environment
ENV CONDA_ENV_PATH=/opt/conda_env

RUN conda create --prefix $CONDA_ENV_PATH python=3.12 -y

# Make RUN commands use the new environment:
SHELL ["conda", "run", "-p", "/opt/conda_env", "/bin/bash", "-c"]

# Install Jupyter Notebook via Conda
RUN conda env create -y environment.yml

# Install additional pip modules that do not have a conda package just yet
RUN conda run pip install python-chess sqlalchemy

# Make port 8888 available to the world outside this container
EXPOSE 8888

# Run Jupyter Notebook when the container launches
# Use the `--ip=0.0.0.0` to make the notebook accessible from outside the container
CMD ["conda", "run", "-p", "/opt/conda_env", "jupyter", "notebook", "--notebook-dir=/semester_project", "--ip='0.0.0.0'", "--port=8888", "--no-browser", "--allow-root", "--NotebookApp.token=''"]