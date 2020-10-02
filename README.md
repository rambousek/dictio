# dictio

## install

```
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
yum install vim mc ruby bash-completion git htop screen wget
group add dictio
```

### view
```
yum install nginx ruby-devel make gcc redhat-rpm-config
gem install sinatra slim mongo i18n json bson puma
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
    root /srv/dictio/public;
    server_name DICTIO;

    location / {
        try_files $uri $uri/index.html @puma;
    }

    location @puma {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        proxy_pass http://sinatra;
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
