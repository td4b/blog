FROM klakegg/hugo:0.79.0

COPY content/ app/content/

COPY packages/ app/

WORKDIR app/
