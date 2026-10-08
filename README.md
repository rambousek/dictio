# dictio

Servers: Rocky Linux 8. Hosts: www.dictio.info (public), edit.dictio.info, admin.dictio.info, files.dictio.info (media).

## install

```
dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf install vim mc bash-completion git htop screen wget
groupadd dictio
```

### view
EL8 default Ruby stream is 2.5, too old for the Gemfile.
```
dnf module reset ruby
dnf module enable ruby:3.3
dnf install ruby ruby-devel make gcc redhat-rpm-config nginx certbot python3-certbot-nginx
gem install bundler
```

certificate
```
certbot certonly --nginx -d www.dictio.info
```

### mongo
https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-red-hat/

## config
### view
```
mkdir /srv/dictio
chgrp dictio /srv/dictio/
chmod g+w /srv/dictio/
git clone git@github.com:rambousek/dictio.git /srv/dictio
cd /srv/dictio
mkdir -p tmp/pids logs
bundle install
cp lib/host-config.rb.sample lib/host-config.rb   # fill in values
./restart.sh
```

`./restart.sh` starts puma (socket `tmp/puma.sock`) or does a phased restart if running.

GeoIP (optional, country stats): `/usr/share/GeoIP/GeoLite2-Country.mmdb`, e.g. via `geoipupdate`.

Deploy: pushes to `main` run `.github/workflows/deploy.yml`, which SSHes to each host (`SSH_USER`/`SSH_KEY` secrets), fetches with `~/.ssh/github` deploy key, `git reset --hard origin/main`, `bundle install`, `./restart.sh`.

/etc/nginx/conf.d/dictio.conf
```
upstream sinatra {
    server unix:/srv/dictio/tmp/puma.sock;
}

server {
   listen 80;
   listen [::]:80;
   server_name www.dictio.info;
   return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    root /srv/dictio/public;
    server_name www.dictio.info;
    ssl_certificate_key /etc/letsencrypt/live/www.dictio.info/privkey.pem;
    ssl_certificate /etc/letsencrypt/live/www.dictio.info/fullchain.pem;
    keepalive_timeout 70;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;


    location / {
        try_files $uri $uri/index.html @puma;
    }

    location ~* ^/video/([^/]*)/([^/]*) {
        proxy_pass http://147.251.22.156/media/$1/$2;
    }
    location ~* ^/thumb/([^/]*)/([^/]*) {
        proxy_pass http://147.251.22.156/media/$1/thumb/$2/thumb.jpg;
    }
    location ~* /sw/(.*) {
        proxy_set_header Host znaky.zcu.cz;
        proxy_pass http://147.228.43.30/proxy/tts/$1?$args;
    }


    location @puma {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        proxy_pass http://sinatra;
    }

    error_page 502 /502.html;
    location = /502.html {
        root /srv/dictio/public/;
        internal;
    }
}
```

### files
/etc/nginx/conf.d/dictio.conf
```
server {
   listen 80;
   listen [::]:80;      
   server_name files.dictio.info;
   return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    root /data/video;
    server_name files.dictio.info;
    ssl_certificate_key /etc/letsencrypt/live/files.dictio.info/privkey.pem;
    ssl_certificate /etc/letsencrypt/live/files.dictio.info/fullchain.pem;
    keepalive_timeout 70;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        autoindex on;
    }
}
```

### mongo
systemctl enable mongod

/etc/mongod.conf - net: bindIp:

crontab: scripts/mongo-counts.sh scripts/mongo-media.sh scripts/cleancomment.rb

### sign
https://github.com/sutton-signwriting/font-db

/etc/systemd/system/signwriting.service

```
[Unit]
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/font-db/server/server.js
WorkingDirectory=/opt/font-db
#Type=forking
Restart=always
StandardOutput=syslog
TimeoutSec=90
SyslogIdentifier=signwriting
User=nobody
Group=wheel
Environment=PATH=/usr/bin:/usr/local/bin
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

```systemctl enable signwriting```

### monitoring
- prometheus
- prometheus-node-exporter
- https://github.com/percona/mongodb_exporter
- puma metrics (yabeda): `127.0.0.1:9395/metrics`, puma control app `127.0.0.1:9293`


