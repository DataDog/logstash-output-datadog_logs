FROM ruby:3.1-bullseye

# Install JRuby using rbenv
RUN apt-get update && apt-get install -y \
    git \
    curl \
    gnupg \
    nodejs \
    npm \
    build-essential \
    openjdk-11-jdk \
    apt-transport-https

# Install Logstash
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - && \
    echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list && \
    apt-get update && apt-get install -y logstash

# Install JRuby
ENV RBENV_ROOT /usr/local/rbenv
ENV PATH $RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH

RUN git clone https://github.com/rbenv/rbenv.git $RBENV_ROOT && \
    git clone https://github.com/rbenv/ruby-build.git $RBENV_ROOT/plugins/ruby-build && \
    $RBENV_ROOT/plugins/ruby-build/install.sh && \
    echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh && \
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc

RUN rbenv install jruby-9.3.9.0 && \
    rbenv global jruby-9.3.9.0

# Create a non-root user for better security
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Install Bundler
RUN gem install bundler

# Fix permissions for Logstash data directory 
RUN mkdir -p /usr/share/logstash/data && \
    chown -R logstash:logstash /usr/share/logstash/data && \
    chmod -R 775 /usr/share/logstash/data && \
    groupadd -f logstash && \
    usermod -aG logstash vscode && \
    chmod -R 775 /usr/share/logstash && \
    chown -R logstash:logstash /usr/share/logstash

WORKDIR /workspace

# Set correct ownership for /workspace
RUN chown -R $USERNAME:$USERNAME /workspace

USER $USERNAME

# Set PATH for the non-root user
ENV PATH="/usr/local/rbenv/bin:/usr/local/rbenv/shims:/usr/share/logstash/bin:${PATH}"
ENV RBENV_ROOT="/usr/local/rbenv"
RUN echo 'eval "$(rbenv init -)"' >> ~/.bashrc

# Setup Ruby environment
RUN echo "gem: --no-document" > ~/.gemrc && \
    mkdir -p /home/$USERNAME/.bundle && \
    echo "---\nBUNDLE_PATH: vendor/bundle" > /home/$USERNAME/.bundle/config 