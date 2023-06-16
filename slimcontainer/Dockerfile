FROM python:3.10-bullseye
ENV DEBIAN_FRONTEND noninteractive
WORKDIR /usr/share/docassemble
RUN apt update
RUN apt install -y locales-all uwsgi libaugeas0 libzbar0 libldap-dev libsasl2-dev
RUN pip install --upgrade pip
COPY docassemble_base ./docassemble_base
COPY docassemble_webapp ./docassemble_webapp
COPY slimcontainer/config.yml /usr/share/docassemble/config/config.yml
RUN pip install -e ./docassemble_base && pip install -e ./docassemble_webapp
RUN python -m nltk.downloader -d /usr/share/nltk_data omw-1.4 wordnet wordnet_ic sentiwordnet
WORKDIR /usr/share/nltk_data/corpora
RUN unzip \*.zip # or just unzip omw-1.4.zip &&  unzip wordnet.zip
WORKDIR /usr/share/docassemble
RUN mkdir log && chown www-data log
RUN mkdir files && chown www-data files

# to enable www-user to write into system python's site-packages
RUN chmod 777 /usr/local/lib/python3.10/site-packages
# to look after nltk only wherer we've prepared them
ENV NLTK_DATA /usr/share/nltk_data
# and don't try to look in /root/nltk_data as uid www-data
ENV APPENGINE_RUNTIME false
EXPOSE 8080
# NLTK_DATA=/usr/share/nltk_data APPENGINE_RUNTIME=false uwsgi --http :8080 --uid www-data --mount da=docassemble.webapp.server:app
CMD ["uwsgi", "--http", ":8080", "--uid", "www-data", "--wsgi", "docassemble.webapp.server:app"]