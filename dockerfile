


##########################
## Set GLOBAL arguments ##
##########################

# Set python version
ARG PYTHON_VERSION=3.10

# Set APP installation folder
ARG APP_HOME=/opt/senave



######################################
## Stage 1: Install Python packages ##
######################################

# Create image
FROM python:${PYTHON_VERSION}-slim AS py_builder

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Set python environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        build-essential && \
    rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /usr/src/app

# Upgrade pip and install dependencies
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip wheel --no-cache-dir --no-deps \
    --wheel-dir /usr/src/app/wheels -r /tmp/requirements.txt



###############################################
## Stage 2: Copy Python installation folders ##
###############################################

# Create image
FROM python:${PYTHON_VERSION}-slim AS py_final

# set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        # install curl and wget \
        curl wget \
        # install firefox (to use it from selenium)
        firefox-esr && \
    rm -rf /var/lib/apt/lists/*

# Download geckodriver (latest version)
RUN curl -s https://api.github.com/repos/mozilla/geckodriver/releases/latest \
 | grep -E 'browser_download_url.*-linux64.tar.gz"' \
 | cut -d : -f 2,3 | tr -d '"' | wget -O /tmp/geckodriver.tar.gz -i -

# Install geckodriver
RUN count=$(ls /tmp/geckodriver.tar.gz | wc -l) && [ $count = 1 ] \
 && tar -xvzf /tmp/geckodriver.tar.gz --directory /usr/local/bin \
 && chmod +x /usr/local/bin/geckodriver \
 || :  # para entender porque :, ver https://stackoverflow.com/a/49348392/5076110

# Install python dependencies from py_builder
COPY --from=py_builder /usr/src/app/wheels /wheels
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --no-cache /wheels/* && \
    rm -rf /wheels



###########################################
## Stage 3: Install management packages  ##
###########################################

# Create image
FROM py_final AS app_builder

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        # install Tini (https://github.com/krallin/tini#using-tini)
        tini \
        # to switch root to a non-root user
        gosu \
        # to see process with pid 1
        htop \
        # to allow edit files
        vim && \
    rm -rf /var/lib/apt/lists/*

# Add Tini (https://github.com/krallin/tini#using-tini)
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]



#############################################
## Stage 4: Setup and run final APP image ##
#############################################

# Create image
FROM app_builder AS final_app_image

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Load source folder
ARG APP_HOME

# Create APP_HOME folder
RUN mkdir -p $APP_HOME

# Copy project
COPY ./*.py $APP_HOME

# Go to APP home folder
WORKDIR $APP_HOME

# Add Tini (https://github.com/krallin/tini#using-tini)
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]

# Run your program under Tini (https://github.com/krallin/tini#using-tini)
CMD [ "python", "main.py" ]
# or docker run your-image /your/program ...



# CONSTRUIR CONTENEDOR
#
# DOCKER_BUILDKIT=1 \
# docker build --force-rm \
# --target final_app_image \
# --tag ghcr.io/aireagro/aireagro_senave_py:v1.0 \
# --file dockerfile .

# docker push ghcr.io/aireagro/aireagro_senave_py:v1.0

# CORRER CONTENEDOR
#
# docker run --name update-reg-senave \
# --volume ./fitosanitarios.csv:/opt/senave/fitosanitarios.csv \
# --volume ./fertilizantes.csv:/opt/senave/fertilizantes.csv \
# --rm ghcr.io/aireagro/aireagro_senave_py:v1.0
