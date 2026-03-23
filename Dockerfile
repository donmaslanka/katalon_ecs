FROM katalonstudio/katalon:latest

USER root

RUN mkdir -p /katalon/project
COPY . /katalon/project

WORKDIR /katalon/project

RUN ls -la /katalon/project && test -f /katalon/project/Jenkins2Smoke.prj

ENTRYPOINT ["katalonc"]
