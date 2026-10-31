FROM ghcr.io/openwebwork/ww-renderer:main@sha256:fc301fd5fd05bc2bc8573b2f7004c303c42aa19a25de0b88123bdb79774d861b

ARG DEBIAN_FRONTEND=noninteractive
ARG OPAM_VERSION=2.5.2
ARG OPAM_SHA256=edfca2630c373b44b7ee1c2f81cd8dcf67468d0db57d6c02158de553ac63dbd4

ENV OPAMROOT=/opt/opam \
    OPAMYES=1 \
    OPAMJOBS=4 \
    OPAMSWITCH=project-rhm \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get -o Acquire::Retries=5 update \
    && apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
        m4 \
        pkg-config \
        python3 \
        python3-pip \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fL --retry 5 --retry-delay 2 \
        -o /usr/local/bin/opam \
        "https://github.com/ocaml/opam/releases/download/${OPAM_VERSION}/opam-${OPAM_VERSION}-x86_64-linux" \
    && echo "${OPAM_SHA256}  /usr/local/bin/opam" | sha256sum -c - \
    && chmod 0755 /usr/local/bin/opam

RUN opam init --disable-sandboxing --no-setup --bare -y \
    && opam switch create project-rhm ocaml-base-compiler.5.5.1 -y \
    && opam install --switch=project-rhm -y \
        dune.3.24.2 \
        menhir.20260209 \
        pprint.20230830

ENV PATH="/opt/opam/project-rhm/bin:${PATH}"

WORKDIR /app

COPY requirements.txt ./
RUN python3 -m pip install --no-cache-dir -r requirements.txt

COPY app.py teacher_builder.py webwork_client.py ./
COPY templates ./templates
COPY static ./static
COPY config_setting ./config_setting
COPY llm_context ./llm_context
COPY tools ./tools
COPY generator ./generator
COPY docker/entrypoint.sh /usr/local/bin/project-rhm-entrypoint

RUN chmod 0755 /usr/local/bin/project-rhm-entrypoint \
    && python3 -c "import json; from pathlib import Path; from app import CONFIG_JSON_PATH, DEFAULT_CONFIG; Path(CONFIG_JSON_PATH).write_text(json.dumps(DEFAULT_CONFIG), encoding='utf-8')" \
    && python3 -c "from app import generate_ml_config; raise SystemExit(0 if generate_ml_config() else 1)" \
    && cd generator \
    && dune build

EXPOSE 5001

ENTRYPOINT ["project-rhm-entrypoint"]
CMD ["python3", "-m", "flask", "--app", "app", "run", "--host=0.0.0.0", "--port=5001"]

