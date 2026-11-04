# JPMC EventCatalog image: the default example catalog built as a static site from the
# workspace packages on this commit, served by nginx on :80. Built from the repo root:
#   docker build -f deploy/jpmc/Dockerfile --build-arg BUILD_LABEL=<label> .
FROM node:24-slim AS build
RUN corepack enable
WORKDIR /repo
COPY . .
ARG BUILD_LABEL=""
ENV BUILD_LABEL=${BUILD_LABEL} CI=true
RUN ./deploy/jpmc/functional-build.sh

FROM nginx:1.29-alpine
COPY deploy/jpmc/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /repo/examples/default/dist /usr/share/nginx/html
ARG BUILD_LABEL=""
RUN printf '{"build":"%s"}\n' "${BUILD_LABEL}" > /usr/share/nginx/html/version.json
EXPOSE 80
