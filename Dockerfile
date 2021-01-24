ARG GODOT_VERSION=3.2.3
ARG GODOT_PROJECT_NAME
ARG GODOT_EXPORT_PRESET=Linux/X11

FROM barichello/godot-ci:$GODOT_VERSION as build
# Exports the Godot project into a .pck file
# Exporting requires an `export_presents.cfg` file in the root directory of the project.
ARG GODOT_EXPORT_PRESET

WORKDIR /src
COPY . .

RUN mkdir export && godot -v --export-pack ${GODOT_EXPORT_PRESET} export/server.pck --quit

FROM ubuntu:focal as godot-server
# Downloads the godot server binary

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /bin

ARG GODOT_VERSION
RUN wget -c https://downloads.tuxfamily.org/godotengine/$GODOT_VERSION/Godot_v$GODOT_VERSION-stable_linux_server.64.zip -O - | funzip > godot-server && chmod u+x godot-server

FROM ubuntu:focal
# The output docker image. Runs the godot server with the exported pck
ARG GODOT_PROJECT_NAME

WORKDIR /app
COPY --from=godot-server /bin/godot-server server
COPY --from=build /src/export/server.pck server.pck

RUN mkdir -p ~/.config/godot \
    && mkdir -p ~/.local/share/godot/app_userdata/${GODOT_PROJECT_NAME} # A workaround for https://github.com/godotengine/godot/issues/44873 to silence the error

ENTRYPOINT ["/app/server"]
