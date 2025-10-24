FROM  debian:bullseye
MAINTAINER Jean-Daniel Gasser <jdgasser@gmail.com>

ENV DEBIAN_FRONTEND=noninteractive
ENV NAGIOS_HOME            /opt/nagios
ENV NAGIOS_USER            nagios
ENV NAGIOS_GROUP           nagios
ENV NAGIOS_CMDUSER         nagios
ENV NAGIOS_CMDGROUP        nagios
ENV NAGIOS_FQDN            nagios.hmt-pro.com
ENV NAGIOSADMIN_USER       nagiosadmin
ENV NAGIOSADMIN_PASS       nagios
ENV APACHE_RUN_USER        nagios
ENV APACHE_RUN_GROUP       nagios
ENV NAGIOS_TIMEZONE        UTC+1
ENV DEBIAN_FRONTEND        noninteractive
ENV NG_NAGIOS_CONFIG_FILE  ${NAGIOS_HOME}/etc/nagios.cfg
ENV NG_CGI_DIR             ${NAGIOS_HOME}/sbin
ENV NG_WWW_DIR             ${NAGIOS_HOME}/share/nagiosgraph
ENV NG_CGI_URL             /cgi-bin
ENV NAGIOS_BRANCH          nagios-4.5.9
ENV NAGIOS_PLUGINS_BRANCH  release-2.4.12
ENV NRPE_BRANCH            nrpe-4.1.3
ENV NCPA_BRANCH            v3.2.1
ENV NSCA_BRANCH            nsca-2.10.3
ENV NAGIOSTV_VERSION       0.8.5


# Configure Postfix pour "Internet Site" (remplace "mondomaine.com" par ton domaine)
RUN echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections && \
    echo "postfix postfix/mynetworks string '127.0.0.0/8'" | debconf-set-selections && \
    echo "postfix postfix/mailname string mondomaine.com" | debconf-set-selections && \
    echo "postfix postfix/destinations string mondomaine.com, localhost.localdomain, localhost" | debconf-set-selections

# Installe Postfix
RUN apt-get update && \
    apt-get install -y postfix && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Active les dépôts non-free et contrib
RUN sed -i 's|main|main contrib non-free|g' /etc/apt/sources.list

ENV DEBIAN_FRONTEND=noninteractive

# Installe les paquets de base
RUN apt-get update && \
    apt-get install -y \
        apache2 \
        apache2-utils \
        autoconf \
        automake \
        bc \
        bsd-mailx \
        build-essential \
        dnsutils \
        fping \
        gettext \
        git \
        gperf \
        iputils-ping \
        jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/

# Installe les paquets PHP
RUN apt-get update && \
    apt-get install -y \
        libapache2-mod-php \
        php-cli \
        php-gd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/

# Installe les paquets Perl
RUN apt-get update && \
    apt-get install -y \
        libcgi-pm-perl \
        libcrypt-des-perl \
        libdbd-mysql-perl \
        libdbd-pg-perl \
        libdbi-perl \
        libdigest-hmac-perl \
        libgd-perl \
        libjson-perl \
        libnet-snmp-perl \
        libnet-tftp-perl \
        libredis-perl \
        librrds-perl \
        libssl-dev \
        libswitch-perl \
        libwww-perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/

# Installe les autres paquets
RUN apt-get update && \
    apt-get install -y \
    #    libldap2-dev \
     #   libmysqlclient-dev \
        libpq-dev \
        m4 \
        netcat \
        parallel \
        python3 \
     #   python3-pip \
        python3-nagiosplugin \
        rsync \
        rsyslog \
     #   smbclient \
        unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/

RUN ( egrep -i "^${NAGIOS_GROUP}"    /etc/group || groupadd $NAGIOS_GROUP    )                         && \
    ( egrep -i "^${NAGIOS_CMDGROUP}" /etc/group || groupadd $NAGIOS_CMDGROUP )
RUN ( id -u $NAGIOS_USER    || useradd --system -d $NAGIOS_HOME -g $NAGIOS_GROUP    $NAGIOS_USER    )  && \
    ( id -u $NAGIOS_CMDUSER || useradd --system -d $NAGIOS_HOME -g $NAGIOS_CMDGROUP $NAGIOS_CMDUSER )

RUN cd /tmp                                           && \
    git clone https://github.com/multiplay/qstat.git  && \
    cd qstat                                          && \
    ./autogen.sh                                      && \
    ./configure                                       && \
    make                                              && \
    make install                                      && \
    make clean                                        && \
    cd /tmp && rm -Rf qstat

RUN cd /tmp                                                                          && \
    git clone https://github.com/NagiosEnterprises/nagioscore.git -b $NAGIOS_BRANCH  && \
    cd nagioscore                                                                    && \
    ./configure                                  \
        --prefix=${NAGIOS_HOME}                  \
        --exec-prefix=${NAGIOS_HOME}             \
        --enable-event-broker                    \
        --with-command-user=${NAGIOS_CMDUSER}    \
        --with-command-group=${NAGIOS_CMDGROUP}  \
        --with-nagios-user=${NAGIOS_USER}        \
        --with-nagios-group=${NAGIOS_GROUP}      \
                                                                                     && \
    make all                                                                         && \
    make install                                                                     && \
    make install-config                                                              && \
    make install-commandmode                                                         && \
    make install-webconf                                                             && \
    make clean                                                                       && \
    cd /tmp && rm -Rf nagioscore


RUN cd /tmp                                                                                   && \
    git clone https://github.com/nagios-plugins/nagios-plugins.git -b $NAGIOS_PLUGINS_BRANCH  && \
    cd nagios-plugins                                                                         && \
    ./tools/setup                                                                             && \
    ./configure                                                 \
        --prefix=${NAGIOS_HOME}                                 \
        --with-ipv6                                             \
        --with-ping-command="/usr/bin/ping -n -U -W %d -c %d %s"  \
        --with-ping6-command="/usr/bin/ping -6 -n -U -W %d -c %d %s"  \
                                                                                              && \
    make                                                                                      && \
    make install                                                                              && \
    make clean                                                                                && \
    mkdir -p /usr/lib/nagios/plugins                                                          && \
    ln -sf ${NAGIOS_HOME}/libexec/utils.pm /usr/lib/nagios/plugins                            && \
    chown root:root ${NAGIOS_HOME}/libexec/check_icmp                                         && \
    chmod u+s ${NAGIOS_HOME}/libexec/check_icmp                                               && \
    cd /tmp && rm -Rf nagios-plugins                                                          


RUN cd /tmp                                                          && \
    git clone https://git.code.sf.net/p/nagiosgraph/git nagiosgraph  && \
    cd nagiosgraph                                                   && \
    ./install.pl --install                                      \
        --prefix /opt/nagiosgraph                               \
        --nagios-user ${NAGIOS_USER}                            \
        --www-user ${NAGIOS_USER}                               \
        --nagios-perfdata-file ${NAGIOS_HOME}/var/perfdata.log  \
        --nagios-cgi-url /cgi-bin                               \
                                                                     && \
    cp share/nagiosgraph.ssi ${NAGIOS_HOME}/share/ssi/common-header.ssi && \
    cd /tmp && rm -Rf nagiosgraph



RUN cd /tmp && \
    wget https://github.com/chriscareycode/nagiostv-react/releases/download/v${NAGIOSTV_VERSION}/nagiostv-${NAGIOSTV_VERSION}.tar.gz && \
    tar xf nagiostv-${NAGIOSTV_VERSION}.tar.gz -C /opt/nagios/share/ && \
    rm /tmp/nagiostv-${NAGIOSTV_VERSION}.tar.gz

RUN sed -i.bak 's/.*\=www\-data//g' /etc/apache2/envvars
RUN export DOC_ROOT="DocumentRoot $(echo $NAGIOS_HOME/share)"                         && \
    sed -i "s,DocumentRoot.*,$DOC_ROOT," /etc/apache2/sites-enabled/000-default.conf  && \
    sed -i "s,</VirtualHost>,<IfDefine ENABLE_USR_LIB_CGI_BIN>\nScriptAlias /cgi-bin/ ${NAGIOS_HOME}/sbin/\n</IfDefine>\n</VirtualHost>," /etc/apache2/sites-enabled/000-default.conf  && \
    ln -s /etc/apache2/mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load

RUN mkdir -p -m 0755 /usr/share/snmp/mibs                     && \
    mkdir -p         ${NAGIOS_HOME}/etc/conf.d                && \
    mkdir -p         ${NAGIOS_HOME}/etc/monitor               && \
    mkdir -p -m 700  ${NAGIOS_HOME}/.ssh                      && \
    chown ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}/.ssh  && \
    touch /usr/share/snmp/mibs/.foo                           && \
    ln -s /usr/share/snmp/mibs ${NAGIOS_HOME}/libexec/mibs    && \
    ln -s ${NAGIOS_HOME}/bin/nagios /usr/local/bin/nagios     && \
    download-mibs && echo "mibs +ALL" > /etc/snmp/snmp.conf

RUN sed -i 's,/bin/mail,/usr/bin/mail,' ${NAGIOS_HOME}/etc/objects/commands.cfg  && \
    sed -i 's,/usr/usr,/usr,'           ${NAGIOS_HOME}/etc/objects/commands.cfg

RUN cp /etc/services /var/spool/postfix/etc/  && \
    echo "smtp_address_preference = ipv4" >> /etc/postfix/main.cf

RUN rm -rf /etc/rsyslog.d /etc/rsyslog.conf

RUN rm -rf /etc/sv/getty-5

ADD overlay /

RUN echo "use_timezone=${NAGIOS_TIMEZONE}" >> ${NAGIOS_HOME}/etc/nagios.cfg


# Copy example config in-case the user has started with empty var or etc

RUN mkdir -p /orig/var                     && \
    mkdir -p /orig/etc                     && \
    cp -Rp ${NAGIOS_HOME}/var/* /orig/var/ && \
    cp -Rp ${NAGIOS_HOME}/etc/* /orig/etc/ 

## Set the permissions for example config
RUN find /opt/nagios/etc \! -user ${NAGIOS_USER} -exec chown ${NAGIOS_USER}:${NAGIOS_GROUP} '{}' + && \
    find /orig/etc \! -user ${NAGIOS_USER} -exec chown ${NAGIOS_USER}:${NAGIOS_GROUP} '{}' +

RUN a2enmod session         && \
    a2enmod session_cookie  && \
    a2enmod session_crypto  && \
    a2enmod auth_form       && \
    a2enmod request

RUN chmod +x /usr/local/bin/start_nagios        && \
    chmod +x /etc/sv/apache/run                 && \
    chmod +x /etc/sv/nagios/run                 && \
    chmod +x /etc/sv/postfix/run                 && \
    chmod +x /etc/sv/rsyslog/run                 && \
    chmod +x /opt/nagiosgraph/etc/fix-nagiosgraph-multiple-selection.sh

RUN cd /opt/nagiosgraph/etc && \
    sh fix-nagiosgraph-multiple-selection.sh

RUN rm /opt/nagiosgraph/etc/fix-nagiosgraph-multiple-selection.sh

# enable all runit services
RUN ln -s /etc/sv/* /etc/service

ENV APACHE_LOCK_DIR /var/run
ENV APACHE_LOG_DIR /var/log/apache2

#Set ServerName and timezone for Apache
RUN echo "ServerName ${NAGIOS_FQDN}" > /etc/apache2/conf-available/servername.conf    && \
    echo "PassEnv TZ" > /etc/apache2/conf-available/timezone.conf            && \
    ln -s /etc/apache2/conf-available/servername.conf /etc/apache2/conf-enabled/servername.conf    && \
    ln -s /etc/apache2/conf-available/timezone.conf /etc/apache2/conf-enabled/timezone.conf

EXPOSE 80 5667 

VOLUME "${NAGIOS_HOME}/var" "${NAGIOS_HOME}/etc" "/var/log/apache2" "/opt/Custom-Nagios-Plugins" "/opt/nagiosgraph/var" "/opt/nagiosgraph/etc"

#CMD [ "/usr/local/bin/start_nagios" ]

#VOLUME "/opt/nagios/var" "/opt/nagios/etc" "/opt/nagios/libexec" "/var/log/apache2" "/usr/share/snmp/mibs" "/opt/Custom-Nagios-Plugins"
COPY update_hosts.sh /usr/local/bin/
COPY update_ssh.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/update_*
CMD [ "bash", "-c", "/usr/local/bin/update_hosts.sh && /usr/local/bin/update_ssh.sh && /usr/local/bin/start_nagios" ]
