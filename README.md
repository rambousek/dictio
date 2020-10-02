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
gem install sinatra slim mongo i18n json bson
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
git clone git@github.com:rambousek/dictio.git
```
