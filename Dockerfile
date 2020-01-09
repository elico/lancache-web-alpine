FROM alpine:latest AS buildenv

LABEL maintainer="Eliezer Croitoru <ngtech1ltd@gmail.com>"
# https://github.com/nginxinc/docker-nginx/blob/master/stable/alpine/Dockerfile
# peek at: https://raw.githubusercontent.com/bntjah/lc-installer/master/installer.sh

ENV NGINX_VERSION 1.16.1

RUN apk add --no-cache \
                gcc \
                libc-dev \
                make \
                openssl-dev \
		openssl \
                pcre-dev \
                zlib-dev \
                linux-headers \
                libxslt-dev \
                gd-dev \
                geoip-dev \
                perl-dev \
                libedit-dev \
                mercurial \
                bash \
                alpine-sdk \
                findutils \
		gettext gettext-dev \
		glib-dev \
		libev \
		libevdev-dev \
		libtool \
		autoconf automake \
		libxpm-dev \
		fakeroot \
		tcpdump \
		udns-dev \
		udns \
		readline-dev \
		ncurses-dev \
		pkgconf \
		httpry git wget curl bash tar xz \
		libmaxminddb-dev libxml2-dev linux-headers paxmark 

# Sources download and deployment 
RUN mkdir -p /build && \
	wget https://nginx.org/download/nginx-1.16.1.tar.gz -O /build/nginx-1.16.1.tar.gz && \
	cd /build && tar xf /build/nginx-1.16.1.tar.gz -C /build/ && \
	cd /build/nginx-1.16.1 && \
	wget http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz -O /build/ngx_cache_purge-2.3.tar.gz && \
	tar xf /build/ngx_cache_purge-2.3.tar.gz -C /build/nginx-1.16.1/ && \
	git clone https://github.com/multiplay/nginx-range-cache/ /build/nginx-range-cache && \
	wget "https://codeload.github.com/wandenberg/nginx-push-stream-module/tar.gz/0.5.1?dummy=/wandenberg-nginx-push-stream-module-0.5.1_GH0.tar.gz" -O /build/wandenberg-nginx-push-stream-module-0.5.1_GH0.tar.gz && \
	tar xf /build/wandenberg-nginx-push-stream-module-0.5.1_GH0.tar.gz -C /build/nginx-1.16.1/ && \
	git clone -b master http://github.com/bntjah/lancache /build/lancache && \
	git clone https://github.com/dlundquist/sniproxy /build/sniproxy && \
	wget https://raw.githubusercontent.com/OpenSourceLAN/origin-docker/master/sniproxy/sniproxy.conf -O /build/etc-sniproxy.conf

## point For any update, upgrade or software addition

# http://hg.nginx.org/nginx/rev/9e25a5380a21 gcc 8 patches
COPY nginx-patches /build/nginx-patches

# Software building phase
## Nginx
RUN cd /build/nginx-1.16.1 && \
	patch -p1 </build/nginx-range-cache/range_filter.patch && \
	./configure --modules-path=/usr/local/nginx/modules \
		--add-module=/build/nginx-1.16.1/ngx_cache_purge-2.3 \
		--add-module=/build/nginx-range-cache \
		--add-module=/build/nginx-1.16.1/nginx-push-stream-module-0.5.1 \
		--with-cc-opt='-I /usr/local/include' \
		--with-ld-opt='-L /usr/local/lib' \
		--conf-path=/usr/local/nginx/nginx.conf \
		--sbin-path=/usr/local/sbin/nginx \
		--pid-path=/var/run/nginx.pid \
		--with-file-aio \
		--with-http_flv_module \
		--with-http_geoip_module=dynamic \
		--with-http_gzip_static_module \
		--with-http_image_filter_module=dynamic \
		--with-http_mp4_module \
		--with-http_realip_module \
		--with-http_slice_module \
		--with-http_stub_status_module \
		--with-pcre \
		--with-http_v2_module \
		--with-stream=dynamic \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-http_ssl_module \
		--with-threads && \
		make -j8 && \
		make DESTDIR=/srv/fakeroot install

## Create binary package 
RUN tar cvfz /srv/lancache-nginx-latest.tar.gz -C /srv/fakeroot/ .

FROM alpine:latest

RUN apk add git curl wget tcpdump udns pcre2 pcre2-tools libtool gettext bash vim nginx nload iftop libev sniproxy \
	libxpm tzdata gd geoip libmaxminddb libxml2 libxslt openssl perl ruby && \
	apk del nginx

COPY --from=buildenv /srv/lancache-nginx-latest.tar.gz /srv/lancache-nginx-latest.tar.gz

RUN mkdir -p /srv && tar xvf /srv/lancache-nginx-latest.tar.gz -C /  && apk add shadow

COPY init-dirs.sh /srv/

## The data exists on the build node and shoud be up to date so no need to store the whole repository
# RUN git clone -b master http://github.com/bntjah/lancache /root/lancache

RUN adduser --system --no-create-home lancache && \
	addgroup --system lancache && \
	usermod -aG lancache lancache && \
	chmod +x /srv/init-dirs.sh && /srv/init-dirs.sh

COPY --from=buildenv /build/lancache/conf/ /usr/local/nginx/

COPY --from=buildenv /build/lancache/hosts /srv/etc/
COPY --from=buildenv /build/etc-sniproxy.conf /srv/etc/sniproxy.conf

COPY gen-vhosts-domains-conf.rb /srv/bin/gen-vhosts-domains-conf.rb
COPY init-hosts.sh /srv/bin/init-hosts.sh

COPY start.sh /srv/bin/start.sh

RUN chmod -v +x /srv/bin/*

EXPOSE 443
EXPOSE 80

COPY lancache-microsoft.domains-txt /srv/lancache-microsoft.domains-txt

VOLUME /srv

CMD [ "/srv/bin/start.sh" ]


