FROM alpine:latest
LABEL PROJECT="webrun/tomcat9"  \
      VERSION="1.0"              \
      AUTHOR="Paulo Corcino"     \
      COMPANY="www.corcino.com.br"
MAINTAINER Paulo Corcino <paulo@corcino.com.br>

###############################################
# AMBIENTE SOFTWELL WEBRUN					  #
###############################################
# 1.0 - 23/02/2020 - Versao Inicial
###############################################

ENV WEBRUN /opt/webrun

# Cria as variáveis de ambiente
# ENV ENCODING ISO-8859-1
ENV ENCODING ISO-8859-1
ENV JAVA_HOME /opt/jdk
ENV PATH ${PATH}:${JAVA_HOME}/bin
ENV JAVA_PACKAGE server-jre
ENV JAVA_OPTS "-XX:+UseG1GC -XX:+OptimizeStringConcat -XX:+UseStringDeduplication -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${CATALINA_HOME}/logs -XX:SurvivorRatio=128 -Dcom.sun.management.jmxremote=true -Duser.language=pt -Duser.country=BR -Duser.region=BR -Duser.timezone=America/Bahia  -Djava.net.preferIPv4Stack=true -Djava.net.preferIPv4Addresses=true -Dsun.jnu.encoding=${ENCODING} -Dfile.encoding=${ENCODING} -Dcom.sun.management.jmxremote.port=18080 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
 
ENV TOMCAT_VERSION_MAJOR 9
ENV TOMCAT_VERSION_FULL  9.0.46
ENV CATALINA_HOME /opt/tomcat

# Expose Web Port
EXPOSE 8080 8443 18080
 
# Fernando Cristovao <fernando.cristovao@perbras.com.br>

# APR
# let "Tomcat Native" live somewhere isolated
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR

# Instala o Java
RUN apk add --no-cache --update --virtual .deps-jav tzdata &&\
	apk add --no-cache openjdk8 &&\
	mkdir -p /opt/jdk &&\
    ln -s /usr/lib/jvm/java-1.8-openjdk/bin ${JAVA_HOME} &&\
	ln -s /usr/lib/jvm/java-1.8-openjdk/include/linux ${JAVA_HOME}/linux &&\ 
	ln -s /usr/lib/jvm/java-1.8-openjdk/include/linux /usr/lib/jvm/java-1.8-openjdk/linux &&\
	rm ${JAVA_HOME}/bin/keytool &&\
	rm ${JAVA_HOME}/bin/orbd && \
	rm ${JAVA_HOME}/bin/pack200 && \
	rm ${JAVA_HOME}/bin/policytool && \
	rm ${JAVA_HOME}/bin/rmid && \
	rm ${JAVA_HOME}/bin/rmiregistry && \
	rm ${JAVA_HOME}/bin/servertool && \
	rm ${JAVA_HOME}/bin/tnameserv && \
	rm ${JAVA_HOME}/bin/unpack200 && \
	rm -rf ${JAVA_HOME}/lib/jfr && \
	rm -rf ${JAVA_HOME}/lib/oblique-fonts 
	
# Instala o Tomcat
RUN apk add --no-cache --update --virtual .fetch-deps curl busybox libgcc pinentry-gtk gnupg ca-certificates tar openssl &&\
	curl -LO https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_VERSION_MAJOR}/v${TOMCAT_VERSION_FULL}/bin/apache-tomcat-${TOMCAT_VERSION_FULL}.tar.gz &&\
	# curl -LO https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_VERSION_MAJOR}/v${TOMCAT_VERSION_FULL}/bin/apache-tomcat-${TOMCAT_VERSION_FULL}.tar.gz.md5 &&\
	# md5sum -c apache-tomcat-${TOMCAT_VERSION_FULL}.tar.gz.md5 &&\
	gunzip -c apache-tomcat-${TOMCAT_VERSION_FULL}.tar.gz | tar -xf - -C /opt &&\
	rm -f apache-tomcat-${TOMCAT_VERSION_FULL}.tar.gz &&\
	# rm -f apache-tomcat-${TOMCAT_VERSION_FULL}.tar.gz.md5 &&\
	ln -s /opt/apache-tomcat-${TOMCAT_VERSION_FULL} $CATALINA_HOME &&\
	rm -rf /${CATALINA_HOME}/webapps/examples ${CATALINA_HOME}/webapps/docs
	
	
# fix permissions (especially for running as non-root)
# https://github.com/docker-library/tomcat/issues/35
RUN	cd ${CATALINA_HOME} &&\
	rm ${CATALINA_HOME}/bin/*.bat &&\
	chmod -R +rX . &&\
	chmod 777 logs temp work
	
# timezone  
ENV TZ=America/Bahia
	
#Tomcat Native Build
RUN nativeBuildDir="$(mktemp -d)"; \
	tar -xf ${CATALINA_HOME}/bin/tomcat-native.tar.gz -C "$nativeBuildDir" --strip-components=1; \
	apk add --no-cache --virtual .native-build-deps \
		apr-dev \
		coreutils \
		gcc \
		libc-dev \
		make \
		cmake \
		git \
		musl-dev \
		gettext-dev \
		wget \
		openssl-dev &&\
	( \
			export CATALINA_HOME=$PWD \
			&& cd $nativeBuildDir/native \
			&& ./configure \
					--libdir=$TOMCAT_NATIVE_LIBDIR \
					--prefix=$CATALINA_HOME \
					--with-apr="$(which apr-1-config)" \
					--with-java-home=/usr/lib/jvm/java-1.8-openjdk \
					--with-ssl=yes \
					--with-os-type=linux \
			&& make -j$(getconf _NPROCESSORS_ONLN) \
			&& make install \
        ) \
		&& runDeps="$( \
                scanelf --needed --nobanner --recursive "$TOMCAT_NATIVE_LIBDIR" \
                        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
                        | sort -u \
                        | xargs -r apk info --installed \
                        | sort -u \
        )" \
        && apk add --no-cache --virtual .tomcat-native-rundeps $runDeps \
		&& rm -rf "$nativeBuildDir" \
        && rm ${CATALINA_HOME}/bin/tomcat-native.tar.gz
  
# Install language pack
RUN localeBuildDir="$(mktemp -d)"; \
	cd $localeBuildDir; \
	wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-2.25-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-bin-2.25-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-i18n-2.25-r0.apk && \
    apk add glibc-bin-2.25-r0.apk glibc-i18n-2.25-r0.apk glibc-2.25-r0.apk &&\
	rm -rf "$localeBuildDir"

# Iterate through all locale and install it
# Note that locale -a is not available in alpine linux, use `/usr/glibc-compat/bin/locale -a` instead
# LOCALE.MD
RUN echo "en_US" >> /locale.md &&\
	echo "pt_BR" >> /locale.md &&\
	echo "pt_PT" >> /locale.md
RUN cat /locale.md | xargs -i /usr/glibc-compat/bin/localedef -i pt_BR -f ${ENCODING} pt_BR.${ENCODING}

# Set the lang, you can also specify it as as environment variable through docker-compose.yml
ENV LANG=pt_BR.${ENCODING} \
    LANGUAGE=pt_BR.${ENCODING}

# remove dependencias
RUN apk del .deps-jav .fetch-deps .native-build-deps .native-build-deps

# limpa todos os apk  
RUN rm -rf /var/cache/apk/*
  
 # Retira ROOT padrão
 # Retira ROOT padrão
RUN rm -rf ${CATALINA_HOME}/webapps &&\
	mkdir -p ${CATALINA_HOME}/webapps

RUN sed -i '$i<Resources cachingAllowed="true" cacheMaxSize="100000" />'  ${CATALINA_HOME}/conf/context.xml 
	
# FIM SCRIPT PADRAO

# DEFINICOES WEBRUN ########################################

# INSTALL HTMLTOPDF
RUN apk add --update --no-cache \
    libgcc libstdc++ libx11 glib libxrender libxext libintl \
    ttf-dejavu ttf-droid ttf-freefont ttf-liberation

# On alpine static compiled patched qt headless wkhtmltopdf (46.8 MB).
# Compilation took place in Travis CI with auto push to Docker Hub see
# BUILD_LOG env. Checksum is printed in line 13685.
COPY --from=madnight/alpine-wkhtmltopdf-builder:0.12.5-alpine3.10-606718795 \
    /bin/wkhtmltopdf /bin/wkhtmltopdf

# COPY WEBRUN
COPY ./webrun.war ${CATALINA_HOME}/webapps/webrun.war
RUN unzip -o ${CATALINA_HOME}/webapps/webrun.war -d ${CATALINA_HOME}/webapps/webrun &&\
    rm -f ${CATALINA_HOME}/webapps/webrun.war

# PASTA WEBRUN
RUN mkdir -p ${WEBRUN} &&\
    mkdir -p ${WEBRUN}/config &&\
    mkdir -p ${WEBRUN}/reports &&\
    mkdir -p ${WEBRUN}/systems

#CRIA INI WEBRUN
RUN echo "[DIR]" >> /usr/lib/webrun.ini &&\
	echo "InstallDir=${WEBRUN}" >> /usr/lib/webrun.ini

#CRIA PASTA STORAGE
RUN mkdir -p ${CATALINA_HOME}/storage &&\
    mkdir -p ${CATALINA_HOME}/ssl &&\
    chmod -R +rwX ${CATALINA_HOME}/storage/;

#CRIA EXECUTE FILE
RUN echo "#!/bin/sh" >> ${WEBRUN}/start.sh &&\
    echo "mv ${CATALINA_HOME}/webapps/webrun ${CATALINA_HOME}/webapps/\$1" >> ${WEBRUN}/start.sh &&\
    echo "mkdir ${WEBRUN}/systems/\$1"  >> ${WEBRUN}/start.sh &&\
    echo "export JAVA_OPTS=\"\${JAVA_OPTS} -server -Xms\$2M -Xmx\$2M\"" >> ${WEBRUN}/start.sh &&\
    echo "${CATALINA_HOME}/bin/catalina.sh run" >> ${WEBRUN}/start.sh
    
RUN chmod +x ${WEBRUN}/start.sh

WORKDIR ${WEBRUN}


