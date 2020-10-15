# dictio

## install

```
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
yum install vim mc ruby bash-completion git htop screen wget
group add dictio
```

### view
```
yum install nginx ruby-devel make gcc redhat-rpm-config certbot python3-certbot-apache mod_ssl
gem install sinatra slim mongo i18n json bson puma
```

certifikát
```
certbot certonly -d beta.dictio.info
```

### mongo
https://docs.mongodb.com/manual/tutorial/install-mongodb-on-red-hat/
```
yum install ruby-devel make gcc redhat-rpm-config
gem install mongo json bson
```

## config
### view
```
mkdir /srv/dictio
chgrp dictio /srv/dictio/
chmod g+w /srv/dictio/
cd /srv/dictio 
git clone git@github.com:rambousek/dictio.git /srv/dictio
```

/etc/nginx/conf.d/dictio.conf
```
upstream sinatra {
    server unix:/srv/dictio/tmp/puma.sock;
}

server {
   listen 80;
   listen [::]:80;
   server_name beta.dictio.info;
   return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    root /srv/dictio/public;
    server_name beta.dictio.info;
    ssl_certificate_key /etc/letsencrypt/live/beta.dictio.info/privkey.pem;
    ssl_certificate /etc/letsencrypt/live/beta.dictio.info/fullchain.pem;
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

```
use dictio
db.entries.aggregate([{"$facet":{"rel": [{"$match": { "meanings.relation.type":{"$nin":["synonym","antonym"]}}},{"$unwind":"$meanings"},{"$unwind":"$meanings.relation"},{"$count":"count"}],"usgrel": [{"$match": { "meanings.usages.relation.type":{"$nin":["synonym","antonym"]}}},{"$unwind":"$meanings"},{"$unwind":"$meanings.usages"},{"$unwind":"$meanings.usages.relation"},{"$count":"count"}],"entries": [{"$count":"count"}] }},{"$merge":"entryStat"}])
```
