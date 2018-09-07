# Create a container for blog.mikaellundin.name
FROM ubuntu:14.04
MAINTAINER Mikael Lundin <hello@mikaellundin.name>

# Install prerequisites
RUN apt-get update && apt-get install -y git git-core curl zlib1g-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties libffi-dev libgdbm-dev libncurses5-dev automake libtool bison libffi-dev libgmp-dev openjdk-7-jre

# # Setup prerequisites for nodejs installatino
# RUN curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
# RUN apt-get install -y nodejs build-essential 

# install ruby 2
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN curl -L https://get.rvm.io | bash -s stable
ENV PATH /usr/local/rvm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN /bin/bash -l -c "rvm requirements"
RUN /bin/bash -l -c "rvm install 2.2.5"
RUN /bin/bash -l -c "rvm use 2.2.5 --default"

# Install jekyll and redcarpet
RUN /bin/bash -l -c "gem install jekyll jekyll-gist jekyll-sitemap mustache pygments.rb rake redcarpet s3_website --no-ri --no-rdoc"
RUN /bin/bash -l -c "gem install sass -v 3.4.21 --no-ri --no-rdoc"

# # Install bower and gulp globally
# RUN npm config set strict-ssl false
# RUN npm config set global false
# RUN npm config set registry="http://registry.npmjs.org/"
# RUN npm install --global bower gulp-cli

# Use local copy of the project, instead of cloning it from github
COPY . /var/www

# Set current working directory
WORKDIR /var/www

# # Download frontend dependencies
# RUN bower install --config.interactive=false --allow-root

# # Download gulp dependencies
# RUN /bin/bash -l -c "npm install --only=dev"

# # Build static assets, once
# RUN /bin/bash -l -c "gulp"

# Install all jekyll dependencies
RUN /bin/bash -l -c "bundle install"

# Set locale
RUN touch /etc/locale.gen
ENV LANG=c.UTF-8
# ENV LANG=en_US.UTF-8
# ENV LANGUAGE=en_US.UTF-8
# ENV LC_ALL=en_US.UTF-8

# Make a volume for the code
VOLUME /var/www

# open port 4000 for http
EXPOSE 4000