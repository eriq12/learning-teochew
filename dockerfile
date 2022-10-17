FROM perl:5.34 as base
RUN apt update && apt upgrade -y
RUN apt install sqlite3
RUN cpan App:cpanminus
RUN cpanm Carton
WORKDIR /usr/src/app
COPY cpanfile /usr/src/app/
RUN cpanm --installdeps .

FROM base as dev
WORKDIR /usr/src/app
COPY . /usr/src/app/
RUN carton install
CMD ["make", "sandbox"]